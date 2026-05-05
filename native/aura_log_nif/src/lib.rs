use rustler::{types::atom::Atom, NifResult, Term};
use std::collections::HashMap;

mod parsers;

rustler::init!(
    "Elixir.AuraLog.Parser.NIF",
    [
        parse_nginx_lines,
        parse_apache_lines,
        parse_json_lines,
        detect_format,
        extract_common_fields,
        tokenize_for_search,
        aggregate_time_window
    ]
);

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_nginx_lines(batch: Vec<String>, _opts: HashMap<String, Term>) -> NifResult<(Atom, Vec<HashMap<String, String>>)> {
    let mut out = Vec::with_capacity(batch.len());
    for line in batch {
        out.push(parsers::parse_nginx(&line));
    }
    Ok((atoms::ok(), out))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_apache_lines(batch: Vec<String>, _opts: HashMap<String, Term>) -> NifResult<(Atom, Vec<HashMap<String, String>>)> {
    let mut out = Vec::with_capacity(batch.len());
    for line in batch {
        out.push(parsers::parse_apache(&line));
    }
    Ok((atoms::ok(), out))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_json_lines(batch: Vec<String>, _opts: HashMap<String, Term>) -> NifResult<(Atom, Vec<HashMap<String, String>>)> {
    let mut out = Vec::with_capacity(batch.len());
    for line in batch {
        out.push(parsers::parse_json(&line));
    }
    Ok((atoms::ok(), out))
}

#[rustler::nif]
fn detect_format(line: String) -> NifResult<(Atom, String)> {
    let (format, _confidence) = parsers::detect_format_hint(&line);
    Ok((atoms::ok(), format.to_string()))
}

#[rustler::nif]
fn extract_common_fields(parsed_row: HashMap<String, String>) -> NifResult<(Atom, HashMap<String, String>)> {
    let mut row = parsed_row;
    if !row.contains_key("level") {
        row.insert("level".to_string(), "info".to_string());
    }
    Ok((atoms::ok(), row))
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

#[rustler::nif(schedule = "DirtyCpu")]
fn aggregate_time_window(
    env: rustler::Env,
    rows: Vec<HashMap<String, String>>,
    _window: i64,
    dimensions: Vec<String>,
) -> NifResult<(Atom, HashMap<String, usize>)> {
    let _ = env;
    let mut grouped: HashMap<String, usize> = HashMap::new();

    for row in rows {
        let key = dimensions
            .iter()
            .map(|d| row.get(d).cloned().unwrap_or_else(|| "unknown".to_string()))
            .collect::<Vec<_>>()
            .join("|");
        *grouped.entry(key).or_insert(0) += 1;
    }

    Ok((atoms::ok(), grouped))
}

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}
