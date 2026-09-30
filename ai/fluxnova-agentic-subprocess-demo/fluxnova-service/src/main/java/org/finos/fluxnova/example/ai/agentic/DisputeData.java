package org.finos.fluxnova.example.ai.agentic;

import java.util.Map;

import org.springframework.stereotype.Component;

/**
 * In-memory stand-in for the bank's customer and card systems. The tool activities in
 * card-dispute-agent.bpmn call it through expressions such as {@code ${disputeData.customer(id)}}.
 *
 * <p>Values are returned as plain strings so they read naturally in the agent's context, which
 * renders each context variable with {@code toString()}.
 */
@Component("disputeData")
public class DisputeData {

    private static final Map<String, String> CUSTOMERS = Map.of(
        "CUST-1001", "name=Jane Doe, tier=GOLD, standing=GOOD, accountAgeYears=6, disputesLast12Months=0",
        "CUST-1002", "name=Omar Haddad, tier=STANDARD, standing=GOOD, accountAgeYears=2, disputesLast12Months=1",
        "CUST-1003", "name=Lena Novak, tier=STANDARD, standing=RESTRICTED, accountAgeYears=1, disputesLast12Months=4");

    private static final Map<String, String> TRANSACTIONS = Map.of(
        "TX-5001", "merchant=StreamPlus Subscriptions, amount=12.99 USD, channel=ONLINE, merchantRisk=LOW",
        "TX-5002", "merchant=QuickTech Electronics, amount=2450.00 USD, channel=ONLINE, merchantRisk=HIGH",
        "TX-5003", "merchant=City Parking, amount=80.00 USD, channel=IN_PERSON, merchantRisk=LOW");

    public String customer(String customerId) {
        return CUSTOMERS.getOrDefault(customerId, "NOT_FOUND");
    }

    public String transaction(String transactionId) {
        return TRANSACTIONS.getOrDefault(transactionId, "NOT_FOUND");
    }
}
