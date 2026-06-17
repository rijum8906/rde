mod tests {
    use rde_theme::{
        defaults::DEFAULT_LIGHT_THEME,
        utils::{theme_name, theme_name_from_key},
    };

    #[test]
    fn test_theme_name_from_key() {
        assert_eq!(
            theme_name_from_key("Default:Light"),
            Some("Default".to_string())
        );
        assert_eq!(
            theme_name_from_key("default:dark"),
            Some("default".to_string())
        );
        assert_eq!(theme_name_from_key("System"), None);
    }

    #[test]
    fn test_theme_name() {
        let theme = DEFAULT_LIGHT_THEME.clone();
        assert_eq!(theme_name(&theme), "Default:Light");
    }
}
