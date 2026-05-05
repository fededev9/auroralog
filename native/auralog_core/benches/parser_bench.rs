use criterion::{black_box, criterion_group, criterion_main, Criterion};
use regex::Regex;

fn bench_http_parse(c: &mut Criterion) {
    let line = r#"127.0.0.1 - - [10/Oct/2000:13:55:36 -0700] "GET /api/items HTTP/1.1" 200 123"#;
    let re = Regex::new(r#"^(?P<host>\S+)\s+\S+\s+\S+\s+\[(?P<ts>[^\]]+)\]\s+"(?P<method>[A-Z]+)\s+(?P<path>\S+)\s+\S+"\s+(?P<status>\d{3})"#)
        .expect("regex compiles");

    c.bench_function("parse_http_line", |b| {
        b.iter(|| {
            let caps = re.captures(black_box(line));
            assert!(caps.is_some());
        })
    });
}

criterion_group!(benches, bench_http_parse);
criterion_main!(benches);
