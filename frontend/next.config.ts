import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Use Webpack for WalletConnect compatibility (not Turbopack)
  webpack: (config) => {
    config.externals.push("pino-pretty", "lokijs", "encoding", "porto");
    config.resolve.fallback = { fs: false, net: false, tls: false };
    return config;
  },
};

export default nextConfig;
