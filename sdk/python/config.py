import os
from pydantic import BaseModel

class AgentConfig(BaseModel):
    # Sui Network RPC
    sui_rpc_url: str = os.getenv("SUI_RPC_URL", "https://fullnode.mainnet.sui.io:443")
    
    # Package & Object IDs (populated upon deployment)
    package_id: str = os.getenv("PACKAGE_ID", "0x0")
    wallet_object_id: str = os.getenv("WALLET_OBJECT_ID", "0x0")
    agent_cap_id: str = os.getenv("AGENT_CAP_ID", "0x0")
    
    # Walrus Storage Configuration
    walrus_publisher_url: str = os.getenv("WALRUS_PUBLISHER_URL", "https://publisher.walrus-testnet.walrus.space")
    walrus_aggregator_url: str = os.getenv("WALRUS_AGGREGATOR_URL", "https://aggregator.walrus-testnet.walrus.space")
    
    # Atoma Network Verifiable Inference
    atoma_api_url: str = os.getenv("ATOMA_API_URL", "https://api.atoma.network/v1")
    atoma_api_key: str = os.getenv("ATOMA_API_KEY", "")
    
    # Agent Parameters
    spend_per_action_mist: int = 10_000_000 # 0.01 SUI
    max_slippage_bps: int = 50 # 0.5%
