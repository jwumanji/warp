use super::*;

fn key(name: &str, scope: &str, created_at: DateTime<Utc>) -> ApiKeyInfo {
    ApiKeyInfo {
        uid: name.to_string(),
        name: name.to_string(),
        key_suffix: "abcd".to_string(),
        scope: scope.to_string(),
        created_at,
        last_used_at: None,
        expires_at: None,
    }
}

#[test]
fn sort_api_keys_sorts_by_name_ascending() {
    let created_at = Utc::now();
    let mut keys = vec![
        key("beta", "Team", created_at),
        key("alpha", "Personal", created_at),
    ];

    sort_api_keys(
        &mut keys,
        Some(ApiKeySortByArg::Name),
        Some(ApiKeySortOrderArg::Asc),
    );

    assert_eq!(keys[0].name, "alpha");
    assert_eq!(keys[1].name, "beta");
}

#[test]
fn sort_api_keys_sorts_by_created_at_descending() {
    let older = Utc::now() - chrono::Duration::days(1);
    let newer = Utc::now();
    let mut keys = vec![key("older", "Team", older), key("newer", "Personal", newer)];

    sort_api_keys(
        &mut keys,
        Some(ApiKeySortByArg::CreatedAt),
        Some(ApiKeySortOrderArg::Desc),
    );

    assert_eq!(keys[0].name, "newer");
    assert_eq!(keys[1].name, "older");
}
