use rustler::{types::atom::Atom, NifResult};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs::OpenOptions;
use std::io::Write;
use std::sync::Mutex;

mod parsers;

static WRITE_LOCK: Mutex<()> = Mutex::new(());

rustler::init!("Elixir.AuraLog.Parser.NIF");

#[derive(Debug, Serialize, Deserialize)]
struct ParsedRow {
    fields: HashMap<String, String>,
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_log_line(line: String) -> NifResult<(Atom, HashMap<String, String>)> {
    let row = ParsedRow {
        fields: parsers::parse_log_line(&line),
    };

    Ok((atoms::ok(), row.fields))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_log_batch(lines: Vec<String>) -> NifResult<(Atom, Vec<HashMap<String, String>>)> {
    let rows = lines
        .iter()
        .map(|line| parsers::parse_log_line(line))
        .collect::<Vec<_>>();
    Ok((atoms::ok(), rows))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn flush_batch_to_duckdb(
    duckdb_path: String,
    rows: Vec<HashMap<String, String>>,
) -> NifResult<(Atom, HashMap<String, i64>)> {
    let _guard = WRITE_LOCK.lock().expect("write lock poisoned");
    let sidecar_path = format!("{duckdb_path}.bulk.ndjson");

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(sidecar_path)
        .map_err(|_| rustler::Error::Term(Box::new("open_failed")))?;

    let mut inserted: i64 = 0;

    for row in rows {
        let payload = serde_json::to_string(&row)
            .map_err(|_| rustler::Error::Term(Box::new("serialization_failed")))?;
        file.write_all(payload.as_bytes())
            .map_err(|_| rustler::Error::Term(Box::new("write_failed")))?;
        file.write_all(b"\n")
            .map_err(|_| rustler::Error::Term(Box::new("write_failed")))?;
        inserted += 1;
    }

    let mut summary = HashMap::new();
    summary.insert("inserted".to_string(), inserted);
    Ok((atoms::ok(), summary))
}

#[rustler::nif]
fn detect_format(line: String) -> NifResult<(Atom, String)> {
    let (format, _confidence) = parsers::detect_format_hint(&line);
    Ok((atoms::ok(), format.to_string()))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn tokenize_for_search(line: String) -> NifResult<(Atom, Vec<String>)> {
    let terms = line
        .to_lowercase()
        .split(|c: char| !c.is_alphanumeric() && c != '_')
        .filter(|t| !t.is_empty())
        .map(|t| t.to_string())
        .collect::<Vec<_>>();
    Ok((atoms::ok(), terms))
}

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}
