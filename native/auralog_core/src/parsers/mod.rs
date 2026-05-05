use once_cell::sync::Lazy;
use regex::Regex;
use serde_json::Value;
use std::collections::HashMap;

static HTTP_LOG_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r#"^(?P<host>\S+)\s+\S+\s+\S+\s+\[(?P<ts>[^\]]+)\]\s+"(?P<method>[A-Z]+)\s+(?P<path>\S+)\s+\S+"\s+(?P<status>\d{3})"#).unwrap()
});
static KV_RE: Lazy<Regex> = Lazy::new(|| {
    Regex::new(r#"(?P<key>[a-zA-Z_][a-zA-Z0-9_\-]*)=(?P<value>[^\s]+)"#).unwrap()
});

pub fn detect_format_hint(line: &str) -> (&'static str, f32) {
    if line.trim_start().starts_with('{') {
        return ("json", 0.95);
    }
    if HTTP_LOG_RE.is_match(line) {
        if line.contains("HTTP/1.1") {
            return ("nginx", 0.9);
        }
        if line.contains("HTTP/1.0") {
            return ("apache", 0.9);
        }
        return ("nginx", 0.7);
    }
    if KV_RE.is_match(line) {
        return ("kv", 0.6);
    }
    ("unknown", 0.2)
}

pub fn parse_log_line(line: &str) -> HashMap<String, String> {
    let (format, confidence) = detect_format_hint(line);
    match format {
        "json" => parse_json(line),
        "nginx" => parse_http_like("nginx", line, confidence),
        "apache" => parse_http_like("apache", line, confidence),
        "kv" => parse_kv_or_raw(line),
        _ => {
            let mut row = parse_kv_or_raw(line);
            row.insert("parse_error".to_string(), "unknown_format".to_string());
            add_inference_metadata(&mut row, "unknown", 0.2);
            row
        }
    }
}

pub fn parse_json(line: &str) -> HashMap<String, String> {
    match serde_json::from_str::<Value>(line) {
        Ok(json) => {
            let mut row = HashMap::new();
            row.insert(
                "service".to_string(),
                json.get("service")
                    .and_then(|v| v.as_str())
                    .unwrap_or("unknown")
                    .to_string(),
            );
            row.insert(
                "level".to_string(),
                json.get("level")
                    .and_then(|v| v.as_str())
                    .unwrap_or("info")
                    .to_string(),
            );
            row.insert(
                "message".to_string(),
                json.get("message")
                    .and_then(|v| v.as_str())
                    .unwrap_or("")
                    .to_string(),
            );
            row.insert(
                "status_code".to_string(),
                json.get("status_code")
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0)
                    .to_string(),
            );
            add_inference_metadata(&mut row, "json", 0.95);
            row
        }
        Err(_) => {
            let mut row = parse_kv_or_raw(line);
            row.insert("parse_error".to_string(), "malformed_json".to_string());
            add_inference_metadata(&mut row, "unknown", 0.3);
            row
        }
    }
}

fn parse_http_like(kind: &str, line: &str, confidence: f32) -> HashMap<String, String> {
    let mut row = HashMap::new();
    row.insert("source".to_string(), kind.to_string());

    if let Some(caps) = HTTP_LOG_RE.captures(line) {
        row.insert("host".to_string(), caps["host"].to_string());
        row.insert("method".to_string(), caps["method"].to_string());
        row.insert("path".to_string(), caps["path"].to_string());
        row.insert("status_code".to_string(), caps["status"].to_string());
        row.insert("message".to_string(), line.to_string());
        add_inference_metadata(&mut row, kind, confidence);
    } else {
        row = parse_kv_or_raw(line);
        row.insert("parse_error".to_string(), "unknown_format".to_string());
        add_inference_metadata(&mut row, "unknown", 0.2);
    }

    row
}

fn parse_kv_or_raw(line: &str) -> HashMap<String, String> {
    let mut row = HashMap::new();
    row.insert("message".to_string(), line.to_string());

    for cap in KV_RE.captures_iter(line) {
        row.insert(cap["key"].to_string(), cap["value"].to_string());
    }

    add_inference_metadata(&mut row, "kv", 0.6);
    row
}

fn add_inference_metadata(row: &mut HashMap<String, String>, detected_format: &str, confidence: f32) {
    row.insert("detected_format".to_string(), detected_format.to_string());
    row.insert("schema_version".to_string(), "v1".to_string());
    row.insert(
        "inference_confidence".to_string(),
        format!("{confidence:.2}"),
    );
    row.insert(
        "inferred_fields_json".to_string(),
        infer_schema_json(row).unwrap_or_else(|| "{}".to_string()),
    );
}

fn infer_schema_json(row: &HashMap<String, String>) -> Option<String> {
    let mut schema = HashMap::new();
    for (key, value) in row {
        let inferred = infer_value_kind(value);
        schema.insert(key.clone(), inferred);
    }
    serde_json::to_string(&schema).ok()
}

fn infer_value_kind(value: &str) -> String {
    if value.parse::<i64>().is_ok() {
        return "integer".to_string();
    }
    if value.parse::<f64>().is_ok() {
        return "float".to_string();
    }
    if value.contains('/') {
        return "path".to_string();
    }
    if value.contains('.') && value.chars().all(|c| c.is_ascii_digit() || c == '.') {
        return "ip_or_decimal".to_string();
    }
    if value.len() >= 20 && value.contains('T') && value.contains(':') {
        return "timestamp_like".to_string();
    }
    "string".to_string()
}
