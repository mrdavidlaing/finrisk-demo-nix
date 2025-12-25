package com.transferx.sanctions;

import java.time.Instant;
import java.util.List;

public class ScreenResponse {
    private boolean cleared;
    private List<String> matchedLists;
    private int riskScore;
    private Instant screenedAt;

    public boolean isCleared() {
        return cleared;
    }

    public void setCleared(boolean cleared) {
        this.cleared = cleared;
    }

    public List<String> getMatchedLists() {
        return matchedLists;
    }

    public void setMatchedLists(List<String> matchedLists) {
        this.matchedLists = matchedLists;
    }

    public int getRiskScore() {
        return riskScore;
    }

    public void setRiskScore(int riskScore) {
        this.riskScore = riskScore;
    }

    public Instant getScreenedAt() {
        return screenedAt;
    }

    public void setScreenedAt(Instant screenedAt) {
        this.screenedAt = screenedAt;
    }
}


