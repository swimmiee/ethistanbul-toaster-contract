import * as dotenv from "dotenv"

import type { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-chai-matchers"
import "hardhat-deploy"
import "hardhat-contract-sizer"
import "@appliedblockchain/chainlink-plugins-fund-link"
import "./tasks"

dotenv.config()

const COMPILER_SETTINGS = {
    optimizer: {
        enabled: true,
        runs: 1000000,
    },
    metadata: {
        bytecodeHash: "none",
    },
}

const MAINNET_RPC_URL =
    process.env.MAINNET_RPC_URL ||
    process.env.ALCHEMY_MAINNET_RPC_URL ||
    "https://eth-mainnet.alchemyapi.io/v2/your-api-key"
const POLYGON_MAINNET_RPC_URL =
    process.env.POLYGON_MAINNET_RPC_URL || "https://polygon-mainnet.alchemyapi.io/v2/your-api-key"
const PRIVATE_KEY = process.env.PRIVATE_KEY
const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            // hardfork: "merge",
            // // If you want to do some forking set `enabled` to true
            forking: {
                // url: "https://arbitrum.llamarpc.com",
                // blockNumber: 151396608,
                // enabled: true,

                enabled: true,
                url: "https://polygon-mainnet.g.alchemy.com/v2/B0_K6Lnh59KS0VqekSSvFEpmfUrUhDGe",
                blockNumber: 50097702,
            },
            // chainId: 31337,
        },

        localhost: {
            chainId: 31337,
        },
        mainnet: {
            url: MAINNET_RPC_URL,
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
            //   accounts: {
            //     mnemonic: MNEMONIC,
            //   },
            saveDeployments: true,
            chainId: 1,
        },
        sepolia: {
            url: "https://eth-sepolia.public.blastapi.io",
            accounts: [PRIVATE_KEY!],
            gasPrice: 8000000000,
        },
        arbitrum: {
            url: "https://arbitrum.llamarpc.com",
            accounts: [PRIVATE_KEY!],
        },
        linea: {
            url: "https://linea.drpc.org",
            accounts: [PRIVATE_KEY!],
        },

        polygon: {
            url: "https://polygon-mainnet.g.alchemy.com/v2/B0_K6Lnh59KS0VqekSSvFEpmfUrUhDGe",
            accounts: [PRIVATE_KEY!],
            gasPrice: 50 * 10 ** 9,
        },
        chiliz_test: {
            url: "https://spicy-rpc.chiliz.com/",
            accounts: [PRIVATE_KEY!],
        },
        scroll: {
            url: "https://rpc.ankr.com/scroll",
            accounts: [PRIVATE_KEY!],
        },
        polygon_zk: {
            url: "https://rpc.ankr.com/polygon_zkevm",
            accounts: [PRIVATE_KEY!],
        },
    },
    contractSizer: {
        runOnCompile: true,
        only: [
            "APIConsumer",
            "KeepersCounter",
            "PriceConsumerV3",
            "RandomNumberConsumer",
            "ZapCalculator",
            "ToasterPool",
            "ToasterStrategy",
        ],
        strict: true,
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        },
        feeCollector: {
            default: 1,
        },
    },
    solidity: {
        compilers: [
            { version: "0.7.5" },
            { version: "0.7.6" },
            {
                version: "0.8.7",
                ...COMPILER_SETTINGS,
            },
            {
                version: "0.6.6",
                ...COMPILER_SETTINGS,
            },
            {
                version: "0.4.24",
                ...COMPILER_SETTINGS,
            },
        ],
        overrides: {
            "@uniswap/v3-core/contracts/libraries/TickBitmap.sol": {
                version: "0.7.5",
            },
            "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol": {
                version: "0.7.5",
            },
        },
    },
    mocha: {
        timeout: 200000, // 200 seconds max for running tests
    },
    typechain: {
        outDir: "typechain",
        target: "ethers-v5",
    },
}

export default config
