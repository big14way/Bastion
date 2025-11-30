import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { mainnet, sepolia } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "Bastion Baskets",
  projectId: "1eebe528ca0ce94a99ceaa2e915058d7",
  chains: [mainnet, sepolia],
  ssr: true,
});
