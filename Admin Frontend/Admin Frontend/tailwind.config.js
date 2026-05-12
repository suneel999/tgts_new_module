/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: "#19aaed", // Sky blue (Indian flag blue)
          green: "#10B981",
          orange: "#F59E0B", // Indian flag orange
          dark: "#1F2937",
        },
      },
      boxShadow: {
        card: "0 1px 2px rgba(0,0,0,0.06), 0 1px 3px rgba(0,0,0,0.1)",
      },
    },
  },
  plugins: [],
};