package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

type TransferRequest struct {
	SenderID    string  `json:"senderId"`
	RecipientID string `json:"recipientId"`
	Amount      float64 `json:"amount"`
	Currency    string  `json:"currency"`
	Rail        string  `json:"rail"` // "SWIFT" or "CRYPTO"
}

type TransferResponse struct {
	ID          string    `json:"id"`
	Status      string    `json:"status"`
	Fee         float64   `json:"fee"`
	TotalAmount float64   `json:"totalAmount"`
	CreatedAt   time.Time `json:"createdAt"`
}

type ComplianceSBOM struct {
	Service string `json:"service"`
	Format  string `json:"format"`
	Path    string `json:"path"`
}

type Vulnerability struct {
	Service   string `json:"service"`
	Severity  string `json:"severity"`
	CVE       string `json:"cve"`
	Package   string `json:"package"`
	Version   string `json:"version"`
}

type GrypeMatch struct {
	Vulnerability struct {
		ID       string `json:"id"`
		Severity string `json:"severity"`
	} `json:"vulnerability"`
	Artifact struct {
		Name    string `json:"name"`
		Version string `json:"version"`
	} `json:"artifact"`
}

type GrypeReport struct {
	Matches []GrypeMatch `json:"matches"`
}

var (
	kycServiceURL      = getEnv("KYC_SERVICE_URL", "http://localhost:8081")
	feeServiceURL      = getEnv("FEE_SERVICE_URL", "http://localhost:8082")
	sanctionsServiceURL = getEnv("SANCTIONS_SERVICE_URL", "http://localhost:8083")
	swiftGatewayURL    = getEnv("SWIFT_GATEWAY_URL", "http://localhost:8086")
	cryptoServiceURL   = getEnv("CRYPTO_SERVICE_URL", "http://localhost:8085")
	auditServiceURL    = getEnv("AUDIT_SERVICE_URL", "http://localhost:8084")
	smokeTestsURL      = getEnv("SMOKE_TESTS_URL", "http://localhost:8090")
)

func main() {
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))

	// CORS
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"http://localhost:3000"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	// Routes
	r.Get("/api/health", healthHandler)
	r.Post("/api/transfer", transferHandler)
	r.Get("/api/transfer/{id}", getTransferHandler)
	r.Get("/api/compliance/sboms", listSBOMsHandler)
	r.Get("/api/compliance/sboms/{service}", getSBOMHandler)
	r.Get("/api/compliance/vulnerabilities", vulnerabilitiesHandler)
	r.Get("/api/smoke-tests", smokeTestsProxyHandler)

	port := getEnv("PORT", "8080")
	log.Printf("API Gateway starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
		"service": "api-gateway",
	})
}

func transferHandler(w http.ResponseWriter, r *http.Request) {
	var req TransferRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request", http.StatusBadRequest)
		return
	}

	// Step 1: KYC verification
	kycOK := verifyKYC(req.SenderID)
	if !kycOK {
		http.Error(w, "KYC verification failed", http.StatusForbidden)
		return
	}

	// Step 2: Sanctions screening
	cleared := screenSanctions(req.SenderID, req.RecipientID, req.Amount)
	if !cleared {
		http.Error(w, "Sanctions screening failed", http.StatusForbidden)
		return
	}

	// Step 3: Calculate fee
	fee := calculateFee(req.Amount, req.Currency, req.Rail)

	// Step 4: Process transfer based on rail
	var transferID string
	if req.Rail == "SWIFT" {
		transferID = processSWIFT(req)
	} else if req.Rail == "CRYPTO" {
		transferID = processCrypto(req)
	} else {
		http.Error(w, "Invalid rail", http.StatusBadRequest)
		return
	}

	response := TransferResponse{
		ID:          transferID,
		Status:      "pending",
		Fee:         fee,
		TotalAmount: req.Amount + fee,
		CreatedAt:   time.Now(),
	}

	// Log to audit service
	logAudit(transferID, req, fee)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func getTransferHandler(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	// Mock response
	response := TransferResponse{
		ID:        id,
		Status:    "completed",
		CreatedAt: time.Now(),
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func listSBOMsHandler(w http.ResponseWriter, r *http.Request) {
	// Look for SBOMs in /data/compliance/sboms
	matches, err := filepath.Glob("/data/compliance/sboms/*.cdx.json")
	if err != nil {
		http.Error(w, "Failed to list SBOMs", http.StatusInternalServerError)
		return
	}

	sboms := []ComplianceSBOM{}
	for _, path := range matches {
		filename := filepath.Base(path)
		serviceName := strings.TrimSuffix(filename, ".cdx.json")
		sboms = append(sboms, ComplianceSBOM{
			Service: serviceName,
			Format:  "CycloneDX",
			Path:    "/compliance/sboms/" + filename,
		})
	}
	
	// If no real SBOMs found, fallback to empty list (or mock if preferred, but empty is better for "real implementation")
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(sboms)
}

func getSBOMHandler(w http.ResponseWriter, r *http.Request) {
	service := chi.URLParam(r, "service")
	
	// Sanitize service name to prevent directory traversal
	if strings.Contains(service, ".") || strings.Contains(service, "/") {
		http.Error(w, "Invalid service name", http.StatusBadRequest)
		return
	}

	path := filepath.Join("/data/compliance/sboms", service+".cdx.json")
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			http.Error(w, "SBOM not found", http.StatusNotFound)
			return
		}
		http.Error(w, "Failed to read SBOM", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(data)
}

func vulnerabilitiesHandler(w http.ResponseWriter, r *http.Request) {
	matches, err := filepath.Glob("/data/compliance/vulns/*.json")
	if err != nil {
		http.Error(w, "Failed to list vulnerabilities", http.StatusInternalServerError)
		return
	}

	allVulns := []Vulnerability{}

	for _, path := range matches {
		filename := filepath.Base(path)
		serviceName := strings.TrimSuffix(filename, ".json")
		
		data, err := os.ReadFile(path)
		if err != nil {
			continue // Skip unreadable files
		}

		var report GrypeReport
		if err := json.Unmarshal(data, &report); err != nil {
			continue // Skip malformed files
		}

		for _, match := range report.Matches {
			allVulns = append(allVulns, Vulnerability{
				Service:  serviceName,
				Severity: match.Vulnerability.Severity,
				CVE:      match.Vulnerability.ID,
				Package:  match.Artifact.Name,
				Version:  match.Artifact.Version,
			})
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(allVulns)
}

// Helper functions
func verifyKYC(userID string) bool {
	// Call kyc-service
	reqBody := map[string]string{
		"userId": userID,
		"email":  userID + "@example.com", // Mock email
	}
	jsonData, _ := json.Marshal(reqBody)
	resp, err := http.Post(fmt.Sprintf("%s/verify", kycServiceURL), "application/json",
		bytes.NewBuffer(jsonData))
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusOK
}

func screenSanctions(senderID, recipientID string, amount float64) bool {
	// Call sanctions-service
	log.Printf("[api-gateway] Calling sanctions-service: senderId=%s, recipientId=%s, amount=%.2f", 
		senderID, recipientID, amount)
	
	reqBody := map[string]interface{}{
		"senderId":    senderID,
		"recipientId": recipientID,
		"amount":      amount,
	}
	jsonData, _ := json.Marshal(reqBody)
	resp, err := http.Post(fmt.Sprintf("%s/screen", sanctionsServiceURL), "application/json", 
		bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("[api-gateway] ERROR: Failed to call sanctions-service: %v", err)
		return false
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		log.Printf("[api-gateway] ERROR: Sanctions-service returned status %d", resp.StatusCode)
		return false
	}
	
	// Parse response to check the cleared field
	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("[api-gateway] ERROR: Failed to parse sanctions-service response: %v", err)
		return false
	}
	
	cleared, ok := result["cleared"].(bool)
	if !ok {
		// If cleared field is missing or not boolean, default to false (fail safe)
		log.Printf("[api-gateway] ERROR: Sanctions-service response missing 'cleared' field")
		return false
	}
	
	log.Printf("[api-gateway] Sanctions screening result: cleared=%v", cleared)
	return cleared
}

func calculateFee(amount float64, currency, rail string) float64 {
	// Mock: call fee-service
	reqBody := map[string]interface{}{
		"amount":   amount,
		"currency": currency,
		"rail":     rail,
	}
	jsonData, _ := json.Marshal(reqBody)
	resp, err := http.Post(fmt.Sprintf("%s/calculate", feeServiceURL), "application/json",
		bytes.NewBuffer(jsonData))
	if err != nil {
		return 0
	}
	defer resp.Body.Close()
	
	var result map[string]float64
	json.NewDecoder(resp.Body).Decode(&result)
	return result["fee"]
}

func processSWIFT(req TransferRequest) string {
	// Call swift-gateway HTTP service
	log.Printf("[api-gateway] Calling swift-gateway: senderId=%s, recipientId=%s, amount=%.2f", 
		req.SenderID, req.RecipientID, req.Amount)
	
	reqBody := map[string]interface{}{
		"senderId":    req.SenderID,
		"recipientId": req.RecipientID,
		"amount":      req.Amount,
		"currency":    req.Currency,
	}
	jsonData, _ := json.Marshal(reqBody)
	resp, err := http.Post(fmt.Sprintf("%s/generate", swiftGatewayURL), "application/json",
		bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("[api-gateway] ERROR: Failed to call swift-gateway: %v", err)
		return ""
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		log.Printf("[api-gateway] ERROR: Swift-gateway returned status %d", resp.StatusCode)
		return ""
	}
	
	var result map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("[api-gateway] ERROR: Failed to parse swift-gateway response: %v", err)
		return ""
	}
	
	transferID := result["id"]
	if transferID == "" {
		transferID = result["reference"]
	}
	
	log.Printf("[api-gateway] SWIFT transfer processed successfully: id=%s", transferID)
	return transferID
}

func processCrypto(req TransferRequest) string {
	// Call crypto-transfer service
	log.Printf("[api-gateway] Calling crypto-transfer service: from=%s, to=%s, amount=%.2f", 
		req.SenderID, req.RecipientID, req.Amount)
	
	reqBody := map[string]interface{}{
		"from":   req.SenderID,
		"to":     req.RecipientID,
		"amount": req.Amount,
	}
	jsonData, _ := json.Marshal(reqBody)
	resp, err := http.Post(fmt.Sprintf("%s/transfer", cryptoServiceURL), "application/json",
		bytes.NewBuffer(jsonData))
	if err != nil {
		log.Printf("[api-gateway] ERROR: Failed to call crypto-transfer service: %v", err)
		return ""
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		log.Printf("[api-gateway] ERROR: Crypto-transfer service returned status %d", resp.StatusCode)
		return ""
	}
	
	var result map[string]string
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		log.Printf("[api-gateway] ERROR: Failed to parse crypto-transfer response: %v", err)
		return ""
	}
	
	txHash := result["txHash"]
	log.Printf("[api-gateway] Crypto transfer processed: txHash=%s", txHash)
	return txHash
}

func logAudit(transferID string, req TransferRequest, fee float64) {
	// Async log to audit service
	go func() {
		log.Printf("[api-gateway] Logging to audit-service: transferId=%s, senderId=%s, recipientId=%s, amount=%.2f", 
			transferID, req.SenderID, req.RecipientID, req.Amount)
		
		auditData := map[string]interface{}{
			"transferId":  transferID,
			"senderId":    req.SenderID,
			"recipientId": req.RecipientID,
			"amount":      req.Amount,
			"currency":    req.Currency,
			"rail":        req.Rail,
			"fee":         fee,
		}
		jsonData, _ := json.Marshal(auditData)
		resp, err := http.Post(fmt.Sprintf("%s/log", auditServiceURL), "application/json",
			bytes.NewBuffer(jsonData))
		if err != nil {
			log.Printf("[api-gateway] ERROR: Failed to log to audit-service: %v", err)
			return
		}
		defer resp.Body.Close()
		
		if resp.StatusCode != http.StatusOK {
			log.Printf("[api-gateway] ERROR: Audit-service returned status %d", resp.StatusCode)
			return
		}
		
		log.Printf("[api-gateway] Successfully logged to audit-service: transferId=%s", transferID)
	}()
}

func smokeTestsProxyHandler(w http.ResponseWriter, r *http.Request) {
	resp, err := http.Get(fmt.Sprintf("%s/run-tests", smokeTestsURL))
	if err != nil {
		http.Error(w, "Smoke tests service unavailable", http.StatusServiceUnavailable)
		return
	}
	defer resp.Body.Close()
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
