export default function Test() {
  return (
    <div style={{ 
      padding: '40px', 
      fontSize: '24px',
      backgroundColor: '#f0f0f0',
      minHeight: '100vh'
    }}>
      <h1 style={{ color: '#ff6600', fontSize: '48px' }}>🎉 React is Working!</h1>
      <p style={{ color: '#333' }}>If you see this, React is rendering correctly.</p>
      <p style={{ color: '#666' }}>Backend: http://localhost:5001/api</p>
      <div style={{ marginTop: '20px', padding: '20px', backgroundColor: 'white', borderRadius: '8px' }}>
        <h2>Test successful! ✅</h2>
        <p>The blank screen issue is in one of the actual components.</p>
      </div>
    </div>
  );
}


