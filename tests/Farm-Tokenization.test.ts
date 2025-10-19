import { describe, expect, it } from "vitest";
import { Simnet } from "@hirosystems/clarinet-sdk";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;
const address2 = accounts.get("wallet_2")!;
const deployer = accounts.get("deployer")!;

const contractName = "Farm-Tokenization";

describe("Farm Tokenization Core Tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("can register a new farm", () => {
    const registerFarm = simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("california"),
        Cl.uint(1000),
        Cl.uint(100),
        Cl.uint(500)
      ],
      address1
    );
    expect(registerFarm.result).toBeOk(Cl.uint(1));
  });

  it("can verify farm as contract owner", () => {
    // First register a farm
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("texas"),
        Cl.uint(500),
        Cl.uint(200),
        Cl.uint(250)
      ],
      address1
    );

    // Verify farm as deployer
    const verifyFarm = simnet.callPublicFn(
      contractName,
      "verify-farm",
      [Cl.uint(1)],
      deployer
    );
    expect(verifyFarm.result).toBeOk(Cl.bool(true));
  });

  it("can purchase shares from verified farm", () => {
    // Register and verify farm
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("iowa"),
        Cl.uint(1000),
        Cl.uint(50),
        Cl.uint(800)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "verify-farm",
      [Cl.uint(1)],
      deployer
    );

    // Purchase shares
    const purchaseShares = simnet.callPublicFn(
      contractName,
      "purchase-shares",
      [Cl.uint(1), Cl.uint(10)],
      address2
    );
    expect(purchaseShares.result).toBeOk(Cl.bool(true));
  });

  it("can get farm details", () => {
    // Register farm
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("florida"),
        Cl.uint(2000),
        Cl.uint(75),
        Cl.uint(1000)
      ],
      address1
    );

    const farmDetails = simnet.callReadOnlyFn(
      contractName,
      "get-farm-details",
      [Cl.uint(1)],
      address1
    );
    expect(farmDetails.result).toBeSome();
  });
});

describe("Farm Insurance Feature Tests", () => {
  it("can create crop insurance policy with correct premium calculation", () => {
    // Register and verify farm first
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("nebraska"),
        Cl.uint(1000),
        Cl.uint(100),
        Cl.uint(400)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "verify-farm",
      [Cl.uint(1)],
      deployer
    );

    // Create insurance policy
    const createPolicy = simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("crop"),
        Cl.uint(50000),
        Cl.uint(365)
      ],
      address1
    );
    expect(createPolicy.result).toBeOk(Cl.uint(1));
  });

  it("can create equipment insurance policy", () => {
    // Register farm
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("california"),
        Cl.uint(800),
        Cl.uint(150),
        Cl.uint(300)
      ],
      address1
    );

    // Create equipment insurance policy
    const createPolicy = simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("equipment"),
        Cl.uint(25000),
        Cl.uint(180)
      ],
      address1
    );
    expect(createPolicy.result).toBeOk(Cl.uint(1));
  });

  it("can create weather insurance policy", () => {
    // Register farm
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("florida"),
        Cl.uint(1200),
        Cl.uint(80),
        Cl.uint(600)
      ],
      address1
    );

    // Create weather insurance policy
    const createPolicy = simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("weather"),
        Cl.uint(75000),
        Cl.uint(270)
      ],
      address1
    );
    expect(createPolicy.result).toBeOk(Cl.uint(1));
  });

  it("can purchase insurance policy", () => {
    // Register farm and create policy
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("texas"),
        Cl.uint(900),
        Cl.uint(120),
        Cl.uint(450)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("crop"),
        Cl.uint(40000),
        Cl.uint(365)
      ],
      address1
    );

    // Purchase insurance
    const purchaseInsurance = simnet.callPublicFn(
      contractName,
      "purchase-insurance",
      [Cl.uint(1)],
      address1
    );
    expect(purchaseInsurance.result).toBeOk(Cl.bool(true));
  });

  it("can file insurance claim", () => {
    // Setup: register farm, create policy, purchase insurance
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("iowa"),
        Cl.uint(1100),
        Cl.uint(90),
        Cl.uint(550)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("weather"),
        Cl.uint(60000),
        Cl.uint(365)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "purchase-insurance",
      [Cl.uint(1)],
      address1
    );

    // File claim
    const fileClaim = simnet.callPublicFn(
      contractName,
      "file-claim",
      [
        Cl.uint(1),
        Cl.uint(15000),
        Cl.stringAscii("Severe drought damaged 80% of crops")
      ],
      address1
    );
    expect(fileClaim.result).toBeOk(Cl.uint(1));
  });

  it("can validate and approve insurance claim", () => {
    // Setup: register farm, create policy, purchase insurance, file claim
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("nebraska"),
        Cl.uint(1000),
        Cl.uint(100),
        Cl.uint(500)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("equipment"),
        Cl.uint(30000),
        Cl.uint(180)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "purchase-insurance",
      [Cl.uint(1)],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "file-claim",
      [
        Cl.uint(1),
        Cl.uint(8000),
        Cl.stringAscii("Tractor engine failure")
      ],
      address1
    );

    // Validate claim as contract owner
    const validateClaim = simnet.callPublicFn(
      contractName,
      "validate-claim",
      [Cl.uint(1), Cl.bool(true)],
      deployer
    );
    expect(validateClaim.result).toBeOk(Cl.bool(true));
  });

  it("can get policy details", () => {
    // Setup: register farm and create policy
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("california"),
        Cl.uint(800),
        Cl.uint(110),
        Cl.uint(400)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("crop"),
        Cl.uint(45000),
        Cl.uint(365)
      ],
      address1
    );

    // Get policy details
    const policyDetails = simnet.callReadOnlyFn(
      contractName,
      "get-policy-details",
      [Cl.uint(1)],
      address1
    );
    expect(policyDetails.result).toBeSome();
  });

  it("can get claim status", () => {
    // Setup: register farm, create policy, purchase insurance, file claim
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("florida"),
        Cl.uint(1200),
        Cl.uint(85),
        Cl.uint(600)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("weather"),
        Cl.uint(70000),
        Cl.uint(365)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "purchase-insurance",
      [Cl.uint(1)],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "file-claim",
      [
        Cl.uint(1),
        Cl.uint(20000),
        Cl.stringAscii("Hurricane damage to farm infrastructure")
      ],
      address1
    );

    // Get claim status
    const claimStatus = simnet.callReadOnlyFn(
      contractName,
      "get-claim-status",
      [Cl.uint(1)],
      address1
    );
    expect(claimStatus.result).toBeSome();
  });

  it("can get premium estimate", () => {
    // Register farm first
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("texas"),
        Cl.uint(1000),
        Cl.uint(100),
        Cl.uint(500)
      ],
      address1
    );

    // Get premium estimate
    const premiumEstimate = simnet.callReadOnlyFn(
      contractName,
      "get-policy-premium-estimate",
      [
        Cl.uint(1),
        Cl.stringAscii("crop"),
        Cl.uint(50000)
      ],
      address1
    );
    expect(premiumEstimate.result).toBeSome();
  });

  it("cannot create policy for non-existent farm", () => {
    const createPolicy = simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(999),
        Cl.stringAscii("crop"),
        Cl.uint(50000),
        Cl.uint(365)
      ],
      address1
    );
    expect(createPolicy.result).toBeErr(Cl.uint(101)); // err-not-found
  });

  it("cannot file claim on inactive policy", () => {
    // Register farm and create policy but don't purchase
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("iowa"),
        Cl.uint(800),
        Cl.uint(120),
        Cl.uint(400)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("crop"),
        Cl.uint(40000),
        Cl.uint(365)
      ],
      address1
    );

    // Try to file claim on unpurchased policy
    const fileClaim = simnet.callPublicFn(
      contractName,
      "file-claim",
      [
        Cl.uint(1),
        Cl.uint(10000),
        Cl.stringAscii("Test claim")
      ],
      address1
    );
    expect(fileClaim.result).toBeErr(Cl.uint(207)); // err-policy-inactive
  });

  it("cannot file claim exceeding coverage amount", () => {
    // Setup: register farm, create policy, purchase insurance
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("nebraska"),
        Cl.uint(900),
        Cl.uint(110),
        Cl.uint(450)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("equipment"),
        Cl.uint(25000),
        Cl.uint(180)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "purchase-insurance",
      [Cl.uint(1)],
      address1
    );

    // Try to file claim exceeding coverage
    const fileClaim = simnet.callPublicFn(
      contractName,
      "file-claim",
      [
        Cl.uint(1),
        Cl.uint(30000),
        Cl.stringAscii("Excessive claim")
      ],
      address1
    );
    expect(fileClaim.result).toBeErr(Cl.uint(203)); // err-insufficient-coverage
  });

  it("cannot validate claim if not contract owner", () => {
    // Setup: register farm, create policy, purchase insurance, file claim
    simnet.callPublicFn(
      contractName,
      "register-farm",
      [
        Cl.stringAscii("california"),
        Cl.uint(1000),
        Cl.uint(100),
        Cl.uint(500)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "create-insurance-policy",
      [
        Cl.uint(1),
        Cl.stringAscii("weather"),
        Cl.uint(50000),
        Cl.uint(365)
      ],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "purchase-insurance",
      [Cl.uint(1)],
      address1
    );
    
    simnet.callPublicFn(
      contractName,
      "file-claim",
      [
        Cl.uint(1),
        Cl.uint(12000),
        Cl.stringAscii("Storm damage")
      ],
      address1
    );

    // Try to validate claim as non-owner
    const validateClaim = simnet.callPublicFn(
      contractName,
      "validate-claim",
      [Cl.uint(1), Cl.bool(true)],
      address2
    );
    expect(validateClaim.result).toBeErr(Cl.uint(100)); // err-owner-only
  });
});
