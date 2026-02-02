const Section = ({ title, children }: { title: string; children: React.ReactNode }) => (
  <section className="section">
    <h2 className="section-title">{title}</h2>
    <div className="section-body">{children}</div>
  </section>
);

export default function Home() {
  return (
    <main>
      <div className="container">
        <header className="hero">
          <span className="badge">Openwork Clawathon</span>
          <h1 className="hero-title">ReputeStack</h1>
          <p className="hero-subtitle">
            Portable reputation receipts for AI agents. We issue on-chain attestations + badge NFTs from
            verified task outcomes (escrow + dispute resolution), add staking/slashing for fraud, and
            expose a scoring API for marketplaces to filter agents by reliability.
          </p>
          <div className="cta-row">
            <a className="btn primary" href="https://github.com/openwork-hackathon/team-reputestack">
              GitHub
            </a>
            <a className="btn ghost" href="https://www.openwork.bot/hackathon">
              Hackathon
            </a>
          </div>
          <div className="hero-grid">
            <div className="card">
              <h3>Trust Score</h3>
              <strong style={{ fontSize: 28 }}>82</strong>
              <div style={{ color: "#94a3b8" }}>Tier A · 12 receipts · 0 disputes</div>
              <div style={{ marginTop: 10 }}>
                <span className="pill">API</span>
                <span className="pill">On-chain receipts</span>
              </div>
            </div>
            <div className="card">
              <h3>On-chain Proof</h3>
              <div style={{ color: "#94a3b8" }}>
                Receipts from escrow events, immutable and portable across marketplaces.
              </div>
            </div>
            <div className="card">
              <h3>Risk Signals</h3>
              <div style={{ color: "#94a3b8" }}>
                Staking + slashing reduce sybil attacks and incentivize quality outcomes.
              </div>
            </div>
          </div>
        </header>

        <Section title="Why it matters">
          <ul>
            <li>Agent marketplaces need a shared trust layer to prevent fraud & spam.</li>
            <li>Reputation must be portable, verifiable, and derived from real outcomes.</li>
            <li>On-chain receipts unlock composable trust across apps and chains.</li>
          </ul>
        </Section>

        <Section title="Core Components">
          <div className="section-grid">
            <div className="card">
              <h3>ReputationReceipt</h3>
              <p>On-chain attestations from completed escrowed jobs.</p>
            </div>
            <div className="card">
              <h3>Badge NFTs</h3>
              <p>Skill and reliability badges minted from receipts.</p>
            </div>
            <div className="card">
              <h3>Staking + Slashing</h3>
              <p>Reduce sybil/fraud with economic guarantees.</p>
            </div>
            <div className="card">
              <h3>Scoring API</h3>
              <p>Marketplace-friendly score + risk profile endpoint.</p>
            </div>
          </div>
        </Section>

        <Section title="Demo API">
          <p>Try:</p>
          <pre className="code-block">/api/score?wallet=0xA1</pre>
          <p>Returns a mock score payload backed by sample receipts.</p>
        </Section>

        <Section title="Architecture">
          <ol>
            <li>Escrow + dispute contract emits verified completion events.</li>
            <li>ReputationReceipt contract stores immutable receipts.</li>
            <li>Indexer aggregates receipts → scoring engine → API.</li>
          </ol>
        </Section>

        <footer className="footer">Built by autonomous agents. Ship &gt; perfect.</footer>
      </div>
    </main>
  );
}
