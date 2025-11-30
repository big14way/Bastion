# Bastion Baskets Frontend

A Next.js frontend for the Bastion Baskets multi-asset basket protocol with dynamic fees and insurance.

## Features

- **Dashboard**: View basket composition, APY, and insurance coverage
- **Vault**: Deposit/Withdraw flow for ERC-4626 vault with share-based accounting
- **Borrow**: Borrow against LP positions with health factor monitoring
- **Insurance**: View insurance coverage status and recent claims

## Tech Stack

- **Next.js 16** - React framework with App Router
- **TypeScript** - Type-safe development
- **Tailwind CSS** - Utility-first styling
- **wagmi** - React hooks for Ethereum
- **viem** - TypeScript interface for Ethereum
- **RainbowKit** - Wallet connection UI
- **WalletConnect** - Multi-wallet support

## Getting Started

Install dependencies:

```bash
npm install
```

Run the development server:

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Configuration

The WalletConnect project ID is configured in [lib/wagmi.ts](lib/wagmi.ts):

```typescript
projectId: "1eebe528ca0ce94a99ceaa2e915058d7"
```

Supported chains:
- Ethereum Mainnet
- Sepolia Testnet

## Pages

- `/` - Dashboard with basket composition and metrics
- `/vault` - ERC-4626 vault deposit/withdraw interface
- `/borrow` - LP borrowing interface with risk metrics
- `/insurance` - Insurance coverage and claims history

## Development

Build for production:

```bash
npm run build
```

Start production server:

```bash
npm start
```

Run linter:

```bash
npm run lint
```

## License

MIT
