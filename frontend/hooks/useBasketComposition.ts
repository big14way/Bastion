import { useReadContracts } from "wagmi";
import { CONTRACTS } from "@/lib/contracts/addresses";
import { ERC20ABI } from "@/lib/contracts/abis";

export interface BasketAsset {
  name: string;
  symbol: string;
  address: string;
  balance: bigint;
  weight: number;
  value: number;
  price: number;
}

export function useBasketComposition() {
  const basketTokens = [
    { name: "Staked Ether", symbol: "stETH", address: CONTRACTS.stETH },
    { name: "Coinbase Staked ETH", symbol: "cbETH", address: CONTRACTS.cbETH },
    { name: "Rocket Pool ETH", symbol: "rETH", address: CONTRACTS.rETH },
    { name: "Ethena USDe", symbol: "USDe", address: CONTRACTS.USDe },
  ];

  const { data, isError, isLoading, refetch } = useReadContracts({
    contracts: basketTokens.flatMap((token) => [
      {
        address: token.address,
        abi: ERC20ABI,
        functionName: "balanceOf",
        args: [CONTRACTS.PoolManager],
      },
      {
        address: token.address,
        abi: ERC20ABI,
        functionName: "symbol",
      },
    ]),
  });

  const assets: BasketAsset[] = basketTokens.map((token, index) => {
    const balanceResult = data?.[index * 2];
    const symbolResult = data?.[index * 2 + 1];

    const balance =
      balanceResult?.status === "success" ? BigInt(balanceResult.result as unknown as bigint) : BigInt(0);
    const symbol =
      symbolResult?.status === "success"
        ? String(symbolResult.result)
        : token.symbol;

    // Mock values for demonstration - would calculate from actual balances
    const mockPrice = 1.0;
    const value = Number(balance) / 1e18 * mockPrice;

    return {
      name: token.name,
      symbol,
      address: token.address,
      balance,
      weight: 0, // Will be calculated based on total
      value,
      price: mockPrice,
    };
  });

  // Calculate weights
  const totalValue = assets.reduce((sum, asset) => sum + asset.value, 0);
  const assetsWithWeights = assets.map((asset) => ({
    ...asset,
    weight: totalValue > 0 ? (asset.value / totalValue) * 100 : 0,
  }));

  return {
    assets: assetsWithWeights,
    totalValue,
    isLoading,
    isError,
    refetch,
  };
}
