/** @type {import('next').NextConfig} */
const nextConfig = {
  webpack: (config) => {
    config.externals.push("pino-pretty", "lokijs", "encoding");
    return config;
  },
  env: {
    NEXT_PUBLIC_TEMPLATE_CLIENT_ID: process.env.NEXT_PUBLIC_TEMPLATE_CLIENT_ID,
},
};

export default nextConfig;