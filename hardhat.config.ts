import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "dotenv/config";
import "hardhat-contract-sizer";

export default {
  etherscan: {
    apiKey: {
      routescan: "routescan", // apiKey is not required, just set a placeholder
    },
    customChains: [
      {
        network: "routescan",
        chainId: 88888,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/88888/etherscan",
          browserURL: "https://routescan.io",
        },
      },
      {
        network: "routescan",
        chainId: 88882,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/88882/etherscan",
          browserURL: "https://routescan.io",
        },
      },
    ],
  },
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
        },
      },
      {
        version: "0.8.9",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "london",
        },
      },
      {
        version: "0.8.0",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "london",
        },
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "london",
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: "london",
        },
      },
    ],
  },
  networks: {
    spicy: {
      allowUnlimitedContractSize: true,
      url: "https://spicy-rpc.chiliz.com/",
      chainId: 88882,
      accounts: [process.env.TESTNET_KEY],
      gas: "auto",
      gasPrice: "auto",
      txFeeCap: "100000000000000000000000000", // 0.1 ether
      runs: 0,
    },
    chiliz: {
      allowUnlimitedContractSize: true,
      url: "https://chiliz.publicnode.com/",
      chainId: 88888,
      accounts: [process.env.MAINNET_KEY],
      gas: "auto",
      gasPrice: "auto",
      txFeeCap: "100000000000000000000000000", // 0.1 ether
      runs: 0,
    },
    routescan: {
      url: "https://chiliz.publicnode.com/",
      accounts: [process.env.PRIVATE_KEY],
    },

    // neon: {
    //   allowUnlimitedContractSize: true,
    //   url: "https://neon-mainnet.everstake.one",
    //   chainId: 245022934,
    //   accounts: [process.env.MAINNET_KEY],
    //   gas: "auto",
    //   gasPrice: "auto",
    //   runs: 0,
    // },
    // neon_devnet: {
    //   allowUnlimitedContractSize: true,
    //   url: "https://devnet.neonevm.org",
    //   chainId: 245022926,
    //   accounts: [process.env.TESTNET_KEY],
    //   gas: "auto",
    //   gasPrice: "auto",
    //   runs: 0,
    // },
  },
  mocha: {
    timeout: 400000000,
  },
};
