use serde::de::DeserializeOwned;
use std::time::Duration;

/// Contactable UA — Open Library asks for this; bare clients get dropped.
pub const USER_AGENT: &str =
    "Koma/2.39 (ebook reader; metadata; https://github.com/WillDera/LNStash)";

/// GET JSON with retries for transient network / 429 / 5xx failures.
pub async fn get_json<T: DeserializeOwned>(
    client: &reqwest::Client,
    url: &str,
) -> Result<T, String> {
    let mut last_err = String::from("request failed");
    for attempt in 0..3u32 {
        if attempt > 0 {
            let ms = 400u64.saturating_mul(1u64 << (attempt - 1));
            tokio::time::sleep(Duration::from_millis(ms)).await;
        }
        let resp = match client
            .get(url)
            .header("User-Agent", USER_AGENT)
            .header("Accept", "application/json")
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => {
                last_err = e.to_string();
                continue;
            }
        };
        let status = resp.status();
        if status.as_u16() == 429 || status.is_server_error() {
            last_err = format!("HTTP {status}");
            continue;
        }
        if !status.is_success() {
            return Err(format!("HTTP {status}"));
        }
        return resp.json::<T>().await.map_err(|e| e.to_string());
    }
    Err(last_err)
}

/// True when the error string looks like a Google Books quota trip.
pub fn is_rate_limited(err: &str) -> bool {
    let lower = err.to_ascii_lowercase();
    lower.contains("429") || lower.contains("too many requests")
}
