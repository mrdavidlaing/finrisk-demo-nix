from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Literal
import math

app = FastAPI(title="Fee Service", version="0.1.0")


class FeeRequest(BaseModel):
    amount: float
    currency: str = "USD"
    rail: Literal["SWIFT", "CRYPTO"]


class FeeResponse(BaseModel):
    amount: float
    currency: str
    rail: str
    fee: float
    total: float
    breakdown: dict


class RateResponse(BaseModel):
    swift: dict
    crypto: dict


def calculate_swift_fee(amount: float) -> float:
    """
    SWIFT fee calculation:
    - 0.5% of amount + $25 flat fee
    - Minimum: $30
    - Maximum: $500
    """
    percentage_fee = amount * 0.005
    flat_fee = 25.0
    total = percentage_fee + flat_fee
    return max(30.0, min(500.0, total))


def calculate_crypto_fee(amount: float) -> float:
    """
    Crypto fee calculation:
    - 0.1% of amount
    - Network gas estimate (mock: $5-15 based on amount)
    """
    percentage_fee = amount * 0.001
    # Mock gas estimate
    if amount < 1000:
        gas_estimate = 5.0
    elif amount < 10000:
        gas_estimate = 10.0
    else:
        gas_estimate = 15.0
    return percentage_fee + gas_estimate


@app.get("/health")
async def health():
    return {"status": "healthy", "service": "fee-service"}


@app.post("/calculate", response_model=FeeResponse)
async def calculate_fee(request: FeeRequest):
    """Calculate transfer fee based on amount, currency, and rail."""
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")

    if request.rail == "SWIFT":
        fee = calculate_swift_fee(request.amount)
        breakdown = {
            "percentage": request.amount * 0.005,
            "flat": 25.0,
            "min_max_applied": fee != (request.amount * 0.005 + 25.0)
        }
    elif request.rail == "CRYPTO":
        fee = calculate_crypto_fee(request.amount)
        breakdown = {
            "percentage": request.amount * 0.001,
            "gas_estimate": fee - (request.amount * 0.001)
        }
    else:
        raise HTTPException(status_code=400, detail="Invalid rail. Must be SWIFT or CRYPTO")

    return FeeResponse(
        amount=request.amount,
        currency=request.currency,
        rail=request.rail,
        fee=round(fee, 2),
        total=round(request.amount + fee, 2),
        breakdown=breakdown
    )


@app.get("/rates", response_model=RateResponse)
async def get_rates():
    """Get current fee schedule."""
    return RateResponse(
        swift={
            "percentage": 0.5,
            "flat": 25.0,
            "min": 30.0,
            "max": 500.0,
            "description": "0.5% + $25 flat (min $30, max $500)"
        },
        crypto={
            "percentage": 0.1,
            "gas_estimate_range": [5.0, 15.0],
            "description": "0.1% + network gas estimate"
        }
    )

def start():
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8082)

if __name__ == "__main__":
    start()
