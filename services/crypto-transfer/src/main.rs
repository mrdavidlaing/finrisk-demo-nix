use axum::{
    extract::Path,
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use tower::ServiceBuilder;
use tower_http::cors::CorsLayer;

type AppState = Arc<RwLock<HashMap<String, Transfer>>>;

#[derive(Clone, Serialize, Deserialize)]
struct TransferRequest {
    from: String,
    to: String,
    amount: f64,
    currency: Option<String>,
}

#[derive(Clone, Serialize, Deserialize)]
struct Transfer {
    tx_hash: String,
    from: String,
    to: String,
    amount: f64,
    currency: String,
    status: String,
    created_at: u64,
}

#[derive(Serialize)]
struct BalanceResponse {
    address: String,
    balance: f64,
    currency: String,
}

#[tokio::main]
async fn main() {
    let state: AppState = Arc::new(RwLock::new(HashMap::new()));

    let app = Router::new()
        .route("/health", get(health))
        .route("/transfer", post(create_transfer))
        .route("/transfer/:txHash", get(get_transfer))
        .route("/wallets/:address/balance", get(get_balance))
        .layer(ServiceBuilder::new().layer(CorsLayer::permissive()))
        .with_state(state);

    let addr = std::net::SocketAddr::from(([0, 0, 0, 0], 8085));
    println!("Crypto Transfer Service listening on port 8085");
    let make_svc = tower::make::Shared::new(app);
    hyper::Server::bind(&addr)
        .serve(make_svc)
        .await
        .unwrap();
}

async fn health() -> Json<serde_json::Value> {
    Json(serde_json::json!({
        "status": "healthy",
        "service": "crypto-transfer"
    }))
}

async fn create_transfer(
    axum::extract::State(state): axum::extract::State<AppState>,
    Json(payload): Json<TransferRequest>,
) -> Result<Json<serde_json::Value>, StatusCode> {
    if payload.amount <= 0.0 {
        return Err(StatusCode::BAD_REQUEST);
    }

    // Generate mock transaction hash
    let tx_hash = format!("0x{:x}", 
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs()
    );

    let transfer = Transfer {
        tx_hash: tx_hash.clone(),
        from: payload.from,
        to: payload.to,
        amount: payload.amount,
        currency: payload.currency.unwrap_or_else(|| "USDT".to_string()),
        status: "pending".to_string(),
        created_at: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs(),
    };

    {
        let mut transfers = state.write().unwrap();
        transfers.insert(tx_hash.clone(), transfer);
    }

    Ok(Json(serde_json::json!({
        "txHash": tx_hash,
        "status": "pending"
    })))
}

async fn get_transfer(
    axum::extract::State(state): axum::extract::State<AppState>,
    Path(tx_hash): Path<String>,
) -> Result<Json<Transfer>, StatusCode> {
    let transfers = state.read().unwrap();
    transfers
        .get(&tx_hash)
        .cloned()
        .map(Json)
        .ok_or(StatusCode::NOT_FOUND)
}

async fn get_balance(Path(address): Path<String>) -> Json<BalanceResponse> {
    // Mock balance - in production, this would query blockchain
    Json(BalanceResponse {
        address,
        balance: 10000.0,
        currency: "USDT".to_string(),
    })
}

