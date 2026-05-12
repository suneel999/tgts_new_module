/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: "#19aaed", // Sky blue (Indian flag blue)
          orange: "#F59E0B", // Indian flag orange
          green: "#10B981", // Indian flag green
          dark: "#1F2937"
        }
      },
      boxShadow: {
        card: "0 1px 2px rgba(0,0,0,0.06), 0 1px 3px rgba(0,0,0,0.1)"
      }
    }
  },
  plugins: []
}

