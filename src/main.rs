#[tokio::main] // ← This macro makes main async
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    print!("Hello, World!");
    Ok(())
}
