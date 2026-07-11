use rde_brightness::app::App;
use rde_core::errors::RdeResult;

#[tokio::main]
async fn main() -> RdeResult<()> {
    let app = App::new()?;
    app.run().await?;
    Ok(())
}
