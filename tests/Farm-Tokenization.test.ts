import { describe, expect, it } from "vitest";
import { readFileSync } from "fs";
import { join } from "path";

// Basic tests for contract structure and functionality
describe("Farm Tokenization Smart Contract", () => {
  it("contract file exists and is readable", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    expect(contractContent).toBeDefined();
    expect(contractContent.length).toBeGreaterThan(0);
  });

  it("contract contains required farm tokenization functions", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for core farm functions
    expect(contractContent).toContain("register-farm");
    expect(contractContent).toContain("verify-farm");
    expect(contractContent).toContain("purchase-shares");
    expect(contractContent).toContain("transfer-shares");
    expect(contractContent).toContain("distribute-revenue");
    expect(contractContent).toContain("claim-earnings");
  });

  it("contract contains required insurance functions", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for insurance functions
    expect(contractContent).toContain("create-insurance-policy");
    expect(contractContent).toContain("purchase-insurance");
    expect(contractContent).toContain("file-claim");
    expect(contractContent).toContain("validate-claim");
    expect(contractContent).toContain("process-payout");
    expect(contractContent).toContain("cancel-policy");
  });

  it("contract has proper error constants", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for core error constants
    expect(contractContent).toContain("err-owner-only");
    expect(contractContent).toContain("err-not-found");
    expect(contractContent).toContain("err-invalid-amount");
    expect(contractContent).toContain("err-unauthorized");
    
    // Check for insurance error constants
    expect(contractContent).toContain("err-policy-not-found");
    expect(contractContent).toContain("err-policy-expired");
    expect(contractContent).toContain("err-insufficient-coverage");
    expect(contractContent).toContain("err-policy-inactive");
  });

  it("contract has proper data structures", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for core data maps
    expect(contractContent).toContain("define-map Farms");
    expect(contractContent).toContain("define-map FarmShares");
    expect(contractContent).toContain("define-map InvestorPortfolio");
    
    // Check for insurance data maps
    expect(contractContent).toContain("define-map InsurancePolicies");
    expect(contractContent).toContain("define-map InsuranceClaims");
    expect(contractContent).toContain("define-map RiskFactors");
  });

  it("contract uses Clarity v3 syntax", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for Clarity v3 features
    expect(contractContent).toContain("define-constant");
    expect(contractContent).toContain("define-data-var");
    expect(contractContent).toContain("define-map");
    expect(contractContent).toContain("define-public");
    expect(contractContent).toContain("define-read-only");
    expect(contractContent).toContain("define-private");
  });

  it("contract has proper validation logic", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for validation patterns
    expect(contractContent).toContain("asserts!");
    expect(contractContent).toContain("unwrap!");
    expect(contractContent).toContain("is-eq");
    expect(contractContent).toContain(">");
    expect(contractContent).toContain(">=");
    expect(contractContent).toContain("<=");
  });

  it("configuration files are present", () => {
    const clarinetPath = join(process.cwd(), "Clarinet.toml");
    const packagePath = join(process.cwd(), "package.json");
    
    expect(readFileSync(clarinetPath, "utf-8")).toContain("Farm-Tokenization");
    expect(readFileSync(packagePath, "utf-8")).toContain("farm-tokenization");
  });

  it("contract has insurance premium calculation logic", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for premium calculation functions
    expect(contractContent).toContain("calculate-premium");
    expect(contractContent).toContain("get-policy-base-rate");
    expect(contractContent).toContain("calculate-size-multiplier");
    expect(contractContent).toContain("get-claim-history-multiplier");
  });

  it("contract initializes risk factors for different locations", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for location risk factor initialization
    expect(contractContent).toContain('"california"');
    expect(contractContent).toContain('"texas"');
    expect(contractContent).toContain('"florida"');
    expect(contractContent).toContain('"nebraska"');
    expect(contractContent).toContain('"iowa"');
  });

  it("contract has proper staking functionality", () => {
    const contractPath = join(process.cwd(), "contracts", "Farm-Tokenization.clar");
    const contractContent = readFileSync(contractPath, "utf-8");
    
    // Check for staking functions
    expect(contractContent).toContain("stake-shares");
    expect(contractContent).toContain("unstake-shares");
    expect(contractContent).toContain("claim-staking-rewards");
    expect(contractContent).toContain("get-reward-multiplier");
  });
});
