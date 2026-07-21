use rde_core::errors::RdeResult;
use rde_wifi::app::Application;

#[tokio::main]
async fn main() -> RdeResult<()> {
    let mut app = Application::global().await.lock().await;
    app.run().await?;

    Ok(())
}
