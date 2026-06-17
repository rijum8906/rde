mod tests {

    use std::collections::HashSet;
    use std::fs;

    use rand::RngExt;
    use rand::distr::Alphanumeric;
    use rde_theme::defaults::DEFAULT_DARK_THEME;
    use rde_theme::models::ThemesList;
    use rde_theme::theme::Theme;
    use rde_theme::utils::create_new_rde_storage;
    use rde_theme::{defaults::DEFAULT_LIGHT_THEME, models::ThemeMode};
    use zbus::message::Body;
    use zbus::{Connection, Proxy};

    async fn setup() -> Proxy<'static> {
        reset_file();
        let connection = Connection::session().await.unwrap();
        Proxy::new(
            &connection,
            "org.rde.Theme",
            "/org/rde/Theme",
            "org.rde.Theme",
        )
        .await
        .unwrap()
    }

    fn reset_file() {
        let theme_storage_path = create_new_rde_storage("test").unwrap();
        let theme_file = ThemesList::default();
        let themes_list_str = serde_json::to_string(&theme_file).unwrap();
        fs::write(
            theme_storage_path.join("themes_list.json"),
            &themes_list_str,
        )
        .unwrap();
    }

    // Generate random alphanumeric string
    fn random_string(length: usize) -> String {
        rand::rng()
            .sample_iter(&Alphanumeric)
            .take(length)
            .map(char::from)
            .collect()
    }

    #[tokio::test]
    async fn test_set_theme() {
        let proxy = setup().await;
        proxy.set_property("CurrentTheme", "Default").await.unwrap();

        // Current theme should reflect the new theme
        let theme: Theme = proxy.get_property("CurrentTheme").await.unwrap();
        assert_eq!(theme.name, "Default".to_string());
    }

    #[tokio::test]
    async fn test_get_theme() {
        let proxy = setup().await;
        let theme: Theme = proxy.get_property("CurrentTheme").await.unwrap();
        assert_eq!(theme.name, "Default".to_string());
        assert_eq!(theme.mode, ThemeMode::Light);
    }

    #[tokio::test]
    async fn test_set_mode() {
        let proxy = setup().await;
        proxy
            .set_property("Mode", ThemeMode::Dark.to_string())
            .await
            .unwrap();

        // Mode should change to dark
        let mode: String = proxy.get_property("Mode").await.unwrap();
        assert_eq!(mode, ThemeMode::Dark.to_string());

        // Current theme should reflect the new mode
        let theme: Theme = proxy.get_property("CurrentTheme").await.unwrap();
        assert_eq!(theme.mode, ThemeMode::Dark);
    }

    #[tokio::test]
    async fn test_get_mode() {
        let proxy = setup().await;
        // Set mode to light
        proxy
            .set_property("Mode", ThemeMode::Light.to_string())
            .await
            .unwrap();
        let mode: String = proxy.get_property("Mode").await.unwrap();
        assert_eq!(mode, ThemeMode::Light.to_string());
    }

    #[tokio::test]
    async fn test_create_theme() {
        let proxy = setup().await;
        let default_theme = DEFAULT_LIGHT_THEME.clone();
        let new_theme_name = random_string(10);

        // Create the Default theme again should return an error
        proxy
            .call_method("CreateTheme", &default_theme)
            .await
            .unwrap_err();

        // Update the name of the theme and create again should succeed
        let mut updated_theme = default_theme;
        updated_theme.name = new_theme_name.clone();
        proxy
            .call_method("CreateTheme", &updated_theme)
            .await
            .unwrap();

        // Set the current theme to this theme
        proxy
            .set_property("CurrentTheme", new_theme_name.clone())
            .await
            .unwrap();

        // Get the current theme
        let theme: Theme = proxy.get_property("CurrentTheme").await.unwrap();
        assert_eq!(theme.name, new_theme_name);
        assert_eq!(theme.mode, ThemeMode::Light);
    }

    #[tokio::test]
    async fn test_list_themes() {
        let proxy = setup().await;
        proxy.call_method("RefreshThemesList", &"").await.unwrap();
        let default_theme = DEFAULT_DARK_THEME.clone();

        let list = proxy.call_method("ListThemes", &"").await.unwrap();
        let body = list.body();
        let json: HashSet<String> = Body::deserialize(&body).unwrap();

        assert_eq!(json.len(), 2);

        // Create two new themes
        let theme_1_name = random_string(10);
        let mut theme_1 = default_theme.clone();
        theme_1.name = theme_1_name;
        proxy.call_method("CreateTheme", &theme_1).await.unwrap();

        let theme_2_name = random_string(10);
        let mut theme_2 = default_theme.clone();
        theme_2.name = theme_2_name;
        proxy.call_method("CreateTheme", &theme_2).await.unwrap();

        let list = proxy.call_method("ListThemes", &theme_1).await.unwrap();
        let body = list.body();
        let json: HashSet<String> = Body::deserialize(&body).unwrap();

        assert_eq!(json.len(), 4);
    }
}
