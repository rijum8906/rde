use rde_brightness::app::App;
use rde_core::errors::RdeResult;

#[tokio::main(flavor = "current_thread")]
async fn main() -> RdeResult<()> {
    let app = App::global();
    app.lock().await.run().await?;
    Ok(())
}
