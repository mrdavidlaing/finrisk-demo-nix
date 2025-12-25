package com.transferx.sanctions;

import org.springframework.web.bind.annotation.*;
import org.springframework.http.ResponseEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/")
public class SanctionsController {

    private static final Logger logger = LoggerFactory.getLogger(SanctionsController.class);

    // Mock sanctions lists (in production, this would query external databases)
    private static final Set<String> OFAC_LIST = Set.of(
        "BADACTOR001", "SUSPECT002", "BLOCKED003"
    );
    
    private static final Set<String> PEP_LIST = Set.of(
        "POLITICIAN001", "OFFICIAL002"
    );

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "healthy");
        response.put("service", "sanctions-service");
        return ResponseEntity.ok(response);
    }

    @PostMapping("/screen")
    public ResponseEntity<ScreenResponse> screen(@RequestBody ScreenRequest request) {
        logger.info("Sanctions screening request: senderId={}, recipientId={}, amount={}", 
            request.getSenderId(), request.getRecipientId(), request.getAmount());
        
        List<String> matchedLists = new ArrayList<>();
        int riskScore = 0;

        // Check OFAC list
        if (OFAC_LIST.contains(request.getSenderId()) || 
            OFAC_LIST.contains(request.getRecipientId())) {
            matchedLists.add("OFAC");
            riskScore += 50;
            logger.warn("OFAC match detected: senderId={}, recipientId={}", 
                request.getSenderId(), request.getRecipientId());
        }

        // Check PEP list
        if (PEP_LIST.contains(request.getSenderId()) || 
            PEP_LIST.contains(request.getRecipientId())) {
            matchedLists.add("PEP");
            riskScore += 30;
            logger.info("PEP match detected: senderId={}, recipientId={}", 
                request.getSenderId(), request.getRecipientId());
        }

        // High-value transaction risk
        if (request.getAmount() > 100000) {
            riskScore += 20;
            logger.info("High-value transaction detected: amount={}", request.getAmount());
        }

        boolean cleared = matchedLists.isEmpty() && riskScore < 50;

        ScreenResponse response = new ScreenResponse();
        response.setCleared(cleared);
        response.setMatchedLists(matchedLists);
        response.setRiskScore(Math.min(100, riskScore));
        response.setScreenedAt(Instant.now());

        logger.info("Sanctions screening result: cleared={}, riskScore={}, matchedLists={}", 
            cleared, riskScore, matchedLists);

        return ResponseEntity.ok(response);
    }

    @GetMapping("/lists/status")
    public ResponseEntity<Map<String, Object>> listsStatus() {
        Map<String, Object> response = new HashMap<>();
        response.put("ofac", Map.of(
            "lastUpdated", "2024-01-15T00:00:00Z",
            "entries", OFAC_LIST.size(),
            "status", "current"
        ));
        response.put("pep", Map.of(
            "lastUpdated", "2024-01-15T00:00:00Z",
            "entries", PEP_LIST.size(),
            "status", "current"
        ));
        return ResponseEntity.ok(response);
    }
}


