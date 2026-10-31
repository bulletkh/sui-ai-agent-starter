module sui_ai_agent_starter::events {
    use sui::object::ID;

    public struct AgentWalletCreated has copy, drop {
        wallet_id: ID,
        admin: address,
        agent_id: address,
        daily_limit: u64,
    }

    public struct ActionExecuted has copy, drop {
        wallet_id: ID,
        amount: u64,
        remaining_budget: u64,
        recipient: address,
        epoch: u64,
    }

    public struct BudgetRefilled has copy, drop {
        wallet_id: ID,
        new_budget: u64,
        epoch: u64,
    }

    public struct EmergencyHaltToggled has copy, drop {
        wallet_id: ID,
        is_halted: bool,
    }

    public struct SpendingLimitUpdated has copy, drop {
        wallet_id: ID,
        old_limit: u64,
        new_limit: u64,
    }
}
