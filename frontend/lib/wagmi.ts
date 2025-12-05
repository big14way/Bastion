import { getDefaultConfig } from "@rainbow-me/rainbowkit";
import { baseSepolia } from "wagmi/chains";

export const config = getDefaultConfig({
  appName: "Bastion Baskets",
  projectId: "1eebe528ca0ce94a99ceaa2e915058d7",
  chains: [baseSepolia],
  ssr: true,
});
