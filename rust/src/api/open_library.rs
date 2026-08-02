use serde::Deserialize;

use super::author::match_score;

const USER_AGENT: &str = "KomaMetadataEngine/0.1 (ebook reader; metadata lookup)";

#[derive(Debug, Clone, Default)]
pub struct OlHit {
    pub title: String,
    pub author: Option<String>,
    pub cover_url: Option<String>,
    pub genres: Vec<String>,
    pub release_date: Option<String>,
    pub remote_id: Option<String>,
}

#[derive(Debug, Deserialize)]
struct SearchResponse {
    docs: Option<Vec<SearchDoc>>,
}

#[derive(Debug, Deserialize)]
struct SearchDoc {
    key: Option<String>,
    title: Option<String>,
    author_name: Option<Vec<String>>,
    first_publish_year: Option<i32>,
    cover_i: Option<i64>,
    subject: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
struct WorkResponse {
    subjects: Option<Vec<String>>,
    first_publish_date: Option<String>,
    covers: Option<Vec<i64>>,
}

pub async fn lookup(
    client: &reqwest::Client,
    title: &str,
    author: Option<&str>,
) -> Result<Option<OlHit>, String> {
    let mut url = format!(
        "https://openlibrary.org/search.json?title={}&limit=8",
        urlencoding::encode(title)
    );
    if let Some(a) = author.map(str::trim).filter(|s| !s.is_empty()) {
        url.push_str(&format!("&author={}", urlencoding::encode(a)));
    }

    let resp = client
        .get(&url)
        .header("User-Agent", USER_AGENT)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?;

    let body: SearchResponse = resp.json().await.map_err(|e| e.to_string())?;
    let docs = body.docs.unwrap_or_default();

    let mut best: Option<(i32, SearchDoc)> = None;
    for doc in docs {
        let cand_title = doc.title.clone().unwrap_or_default();
        let authors = doc.author_name.clone().unwrap_or_default();
        let score = match_score(title, author, &cand_title, &authors);
        if score <= 0 {
            continue;
        }
        match &best {
            None => best = Some((score, doc)),
            Some((s, _)) if score > *s => best = Some((score, doc)),
            _ => {}
        }
    }

    let Some((_score, doc)) = best else {
        return Ok(None);
    };

    let work_key = doc.key.clone();
    let mut genres = doc
        .subject
        .unwrap_or_default()
        .into_iter()
        .take(12)
        .collect::<Vec<_>>();
    let mut release_date = doc.first_publish_year.map(|y| format!("{y:04}-01-01"));
    let mut cover_url = doc
        .cover_i
        .map(|id| format!("https://covers.openlibrary.org/b/id/{id}-L.jpg"));

    // Enrich from the work endpoint when we have a key.
    if let Some(ref key) = work_key {
        if let Ok(work) = fetch_work(client, key).await {
            if genres.is_empty() {
                genres = work.subjects.unwrap_or_default().into_iter().take(12).collect();
            }
            if release_date.is_none() {
                release_date = normalize_date(work.first_publish_date);
            }
            if cover_url.is_none() {
                if let Some(id) = work.covers.and_then(|c| c.into_iter().next()) {
                    cover_url =
                        Some(format!("https://covers.openlibrary.org/b/id/{id}-L.jpg"));
                }
            }
        }
    }

    let author_name = doc
        .author_name
        .and_then(|names| names.into_iter().next());

    Ok(Some(OlHit {
        title: doc.title.unwrap_or_else(|| title.to_string()),
        author: author_name,
        cover_url,
        genres,
        release_date,
        remote_id: work_key,
    }))
}

async fn fetch_work(client: &reqwest::Client, key: &str) -> Result<WorkResponse, String> {
    let path = if key.starts_with('/') {
        key.to_string()
    } else {
        format!("/{key}")
    };
    let url = format!("https://openlibrary.org{path}.json");
    let resp = client
        .get(&url)
        .header("User-Agent", USER_AGENT)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .error_for_status()
        .map_err(|e| e.to_string())?;
    resp.json().await.map_err(|e| e.to_string())
}

fn normalize_date(raw: Option<String>) -> Option<String> {
    let raw = raw?.trim().to_string();
    if raw.is_empty() {
        return None;
    }
    // Already ISO-ish
    if raw.len() >= 10 && raw.as_bytes()[4] == b'-' {
        return Some(raw[..10].to_string());
    }
    // Year only
    if raw.len() == 4 && raw.chars().all(|c| c.is_ascii_digit()) {
        return Some(format!("{raw}-01-01"));
    }
    Some(raw)
}

#[cfg(test)]
mod tests {
    use super::normalize_date;

    #[test]
    fn normalize_year() {
        assert_eq!(normalize_date(Some("1937".into())), Some("1937-01-01".into()));
    }

    #[test]
    fn normalize_iso() {
        assert_eq!(
            normalize_date(Some("1937-09-21".into())),
            Some("1937-09-21".into())
        );
    }
}
