// Copyright (c) 2010 Satoshi Nakamoto
// Copyright (c) 2009-2021 The Bitcoin Core developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or http://www.opensource.org/licenses/mit-license.php.

#include <kernel/chainparams.h>

#include <arith_uint256.h>
#include <chainparamsseeds.h>
#include <consensus/amount.h>
#include <consensus/merkle.h>
#include <consensus/params.h>
#include <hash.h>
#include <kernel/messagestartchars.h>
#include <logging.h>
#include <primitives/block.h>
#include <primitives/transaction.h>
#include <script/interpreter.h>
#include <script/script.h>
#include <uint256.h>
#include <util/chaintype.h>
#include <util/strencodings.h>

#include <algorithm>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <type_traits>

static CBlock CreateGenesisBlock(const char* pszTimestamp, const CScript& genesisOutputScript, uint32_t nTime, uint32_t nNonce, uint32_t nBits, int32_t nVersion, const CAmount& genesisReward)
{
    // Genesis block

    // MainNet:

    //CBlock(hash=000001faef25dec4fbcf906e6242621df2c183bf232f263d0ba5b101911e4563, ver=1, hashPrevBlock=0000000000000000000000000000000000000000000000000000000000000000, hashMerkleRoot=12630d16a97f24b287c8c2594dda5fb98c9e6c70fc61d44191931ea2aa08dc90, nTime=1393221600, nBits=1e0fffff, nNonce=164482, vtx=1, vchBlockSig=)
    //  Coinbase(hash=12630d16a9, nTime=1393221600, ver=1, vin.size=1, vout.size=1, nLockTime=0)
    //    CTxIn(COutPoint(0000000000, 4294967295), coinbase 00012a24323020466562203230313420426974636f696e2041544d7320636f6d6520746f20555341)
    //    CTxOut(empty)
    //  vMerkleTree: 12630d16a9

    // TestNet:

    //CBlock(hash=0000724595fb3b9609d441cbfb9577615c292abf07d996d3edabc48de843642d, ver=1, hashPrevBlock=0000000000000000000000000000000000000000000000000000000000000000, hashMerkleRoot=12630d16a97f24b287c8c2594dda5fb98c9e6c70fc61d44191931ea2aa08dc90, nTime=1393221600, nBits=1f00ffff, nNonce=216178, vtx=1, vchBlockSig=)
    //  Coinbase(hash=12630d16a9, nTime=1393221600, ver=1, vin.size=1, vout.size=1, nLockTime=0)
    //    CTxIn(COutPoint(0000000000, 4294967295), coinbase 00012a24323020466562203230313420426974636f696e2041544d7320636f6d6520746f20555341)
    //    CTxOut(empty)
    //  vMerkleTree: 12630d16a9

    CMutableTransaction txNew;
    txNew.nVersion = 1;
    txNew.nTime = nTime;
    txNew.vin.resize(1);
    txNew.vout.resize(1);
    txNew.vin[0].scriptSig = CScript() << 0 << CScriptNum(42) << std::vector<unsigned char>((const unsigned char*)pszTimestamp, (const unsigned char*)pszTimestamp + strlen(pszTimestamp));
    txNew.vout[0].nValue = genesisReward;

    CBlock genesis;
    genesis.nTime    = nTime;
    genesis.nBits    = nBits;
    genesis.nNonce   = nNonce;
    genesis.nVersion = nVersion;
    genesis.vtx.push_back(MakeTransactionRef(std::move(txNew)));
    genesis.hashPrevBlock.SetNull();
    genesis.hashMerkleRoot = BlockMerkleRoot(genesis);
    return genesis;
}

/**
 * Build the genesis block. Note that the output of its generation
 * transaction cannot be spent since it did not originally exist in the
 * database.
 */
static CBlock CreateGenesisBlock(uint32_t nTime, uint32_t nNonce, uint32_t nBits, int32_t nVersion, const CAmount& genesisReward)
{
    // CodexaCoin genesis timestamp phrase: a verifiable, dated financial-news
    // headline (mirrors Bitcoin's own "Chancellor on brink of second bailout
    // for banks" convention). Kept short and quoted in full (not truncated)
    // to fit the 100-byte coinbase scriptSig consensus limit. See
    // PARAMETERS.md section 8 for the source.
    const char* pszTimestamp = "CNBC 29/Jul/2026 Fed meeting recap: July 2026";
    const CScript genesisOutputScript = CScript() << ParseHex("04678afdb0fe5548271967f1a67130b7105cd6a828e03909a67962e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a4c702b6bf11d5f") << OP_CHECKSIG;
    return CreateGenesisBlock(pszTimestamp, genesisOutputScript, nTime, nNonce, nBits, nVersion, genesisReward);
}

/**
 * CodexaCoin: brute-force nNonce for a genesis block satisfying nBits, reusing
 * the exact same CreateGenesisBlock() (same pszTimestamp, same output script)
 * every CChainParams subclass in this file already calls -- so there is no
 * separate reimplementation of the header/coinbase serialization to get
 * subtly wrong. Used by contrib tooling (see PARAMETERS.md section 8/9) to
 * regenerate genesis nTime/nNonce/hash whenever network params change.
 */
CBlock FindGenesisBlock(uint32_t nTime, uint32_t nBits, int32_t nVersion, const CAmount& genesisReward, uint32_t& nNonceOut)
{
    arith_uint256 bnTarget;
    bnTarget.SetCompact(nBits);
    for (uint32_t nonce = 0;; ++nonce) {
        CBlock block = CreateGenesisBlock(nTime, nonce, nBits, nVersion, genesisReward);
        // CodexaCoin/Blackcoin: proof-of-work is checked against
        // GetPoWHash() (scrypt), not GetHash() (SHA256d, and only for
        // nVersion > 6 at that -- see primitives/block.cpp). ConnectBlock's
        // CheckBlockHeader() calls CheckProofOfWork(block.GetPoWHash(), ...)
        // unconditionally, regardless of block version.
        if (UintToArith256(block.GetPoWHash()) <= bnTarget) {
            nNonceOut = nonce;
            return block;
        }
        if (nonce == std::numeric_limits<uint32_t>::max()) {
            throw std::runtime_error("FindGenesisBlock: exhausted nNonce range without finding a valid hash; try a different nTime");
        }
    }
}

/**
 * Main network on which people trade goods and services.
 */
class CMainParams : public CChainParams {
public:
    CMainParams() {
        m_chain_type = ChainType::MAIN;
        consensus.signet_blocks = false;
        consensus.signet_challenge.clear();
        consensus.nMaxReorganizationDepth = 500;
        consensus.CSVHeight = 0; // CodexaCoin: fresh chain, active from genesis (no legacy history to preserve)
        consensus.SegwitHeight = 0; // CodexaCoin: fresh chain, active from genesis
        consensus.MinBIP9WarningHeight = 0;
        consensus.powLimit = uint256S("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimit = uint256S("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimitV2 = uint256S("000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.nTargetTimespan = 16 * 60; // 16 mins
        consensus.nTargetSpacingV1 = 60;
        consensus.nTargetSpacing = 64; // CodexaCoin: unchanged from Blackcoin default (PARAMETERS.md)
        consensus.fPowAllowMinDifficultyBlocks = false;
        consensus.fPowNoRetargeting = false;
        consensus.fPoSNoRetargeting = false;
        consensus.nRuleChangeActivationThreshold = 12000; // 80% of 15000
        consensus.nMinerConfirmationWindow = 15000; // nTargetTimespan / nTargetSpacing * 1000
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].bit = 28;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].min_activation_height = 0; // No activation delay

        // Deployment of SegWit (BIP141, BIP143, and BIP147)
        // CodexaCoin: fresh chain, SegWit active from genesis (SegwitHeight = 0 above);
        // this deployment entry is unused for buried deployments but left NEVER_ACTIVE
        // for cleanliness/consistency with the other version-bits slots.
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].bit = 1;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].min_activation_height = 0; // No activation delay

        // Deployment of Taproot (BIPs 340-342)
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].min_activation_height = 0; // No activation delay

        consensus.nProtocolV1RetargetingFixedTime = 1395631999;
        consensus.nProtocolV2Time = 1407053625;
        consensus.nProtocolV3Time = 1444028400;
        consensus.nProtocolV3_1Time = 1713938400;
        consensus.nLastPOWBlock = 500; // CodexaCoin: founder premine window, see PARAMETERS.md section 5
        consensus.nStakeTimestampMask = 0xf; // 15
        consensus.nCoinbaseMaturity = 500;

        // CodexaCoin: 14,000,000,000 CAC premine, split evenly across the
        // 500-block PoW window above (28,000,000 CAC/block, exact, no
        // remainder). See PARAMETERS.md section 5.
        consensus.nPremineTotal = CAmount{14000000000} * COIN;
        // CodexaCoin: coin-age-proportional staking reward (PARAMETERS.md
        // section 6 / spec Appendix A). 1368 bp = 13.68%/yr = 1.14%/mo,
        // uncalibrated default pending the regtest maturity-drag test.
        consensus.nStakeRewardAnnualBP = 1368;
        consensus.nStakeRewardAgeCapSeconds = 60 * 24 * 60 * 60; // 60 days

        // CodexaCoin: fresh chain, zeroed pending real chain work (PARAMETERS.md
        // instruction: "Zero out chainTxData and nMinimumChainWork appropriately
        // for a new chain").
        consensus.nMinimumChainWork = uint256{};
        consensus.defaultAssumeValid = uint256{};

        /**
         * The message start string is designed to be unlikely to occur in normal data.
         * The characters are rarely used upper ASCII, not valid as UTF-8, and produce
         * a large 32-bit integer with any alignment.
         */
        pchMessageStart[0] = 0x74;
        pchMessageStart[1] = 0x80;
        pchMessageStart[2] = 0x2a;
        pchMessageStart[3] = 0xa6;
        nDefaultPort = 16210;
        m_assumed_blockchain_size = 1;

        // CodexaCoin: genesis mined by contrib/genesis/generate_genesis.cpp
        // (see PARAMETERS.md section 8). nNonce found by brute force against
        // GetPoWHash() (scrypt), not GetHash().
        genesis = CreateGenesisBlock(1785326400, 2473299, 0x1e0fffff, 7, 0);
        consensus.hashGenesisBlock = genesis.GetHash();
        assert(consensus.hashGenesisBlock == uint256S("0xecf4dfc81beeb2a992ee169e1fc349144e48108d7a03f7fb6d619c2bd845038e"));
        assert(genesis.hashMerkleRoot == uint256S("0x089c9664d716a35a805093b15b0dd6e9f58e84ca21a176c2783a377d23ef6b22"));

        // Note that of those which support the service bits prefix, most only support a subset of
        // possible options.
        // This is fine at runtime as we'll fall back to using them as an addrfetch if they don't support the
        // service bits we want, but we should get them updated to support all service bits wanted by any
        // release ASAP to avoid it where possible.
        // CodexaCoin: TODO placeholders -- no real seed infrastructure exists
        // yet. See PARAMETERS.md section 9 / Phase 2 deliverables.
        vSeeds.emplace_back("seed1.codexacoin.example"); // TODO: stand up real seed node
        vSeeds.emplace_back("seed2.codexacoin.example"); // TODO: stand up real seed node

        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,28);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,63);
        base58Prefixes[SECRET_KEY] =     std::vector<unsigned char>(1,156);
        base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x88, 0xB2, 0x1E};
        base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x88, 0xAD, 0xE4};

        bech32_hrp = "cac";

        // CodexaCoin: no fixed-seed IP list exists yet for a chain that
        // hasn't launched. Empty until Phase 2/7 seed infrastructure is live.
        vFixedSeeds.clear();

        fDefaultConsistencyChecks = false;
        m_is_mockable_chain = false;

        // CodexaCoin: fresh chain -- checkpoints reset to genesis only, per
        // PARAMETERS.md instruction. The 500-block premine window's hashes
        // get appended here once mined (PARAMETERS.md section 9 TODO #2).
        checkpointData = {
            {
                {0, consensus.hashGenesisBlock},
            }
        };

        m_assumeutxo_data = {
            // TODO to be specified in a future patch.
        };

        chainTxData = ChainTxData{
            // CodexaCoin: zeroed, no real chain exists yet (PARAMETERS.md instruction)
            .nTime    = 0,
            .nTxCount = 0,
            .dTxRate  = 0,
        };

        // CodexaCoin: no dev fund address generated yet -- TODO before
        // mainnet launch. Left empty (dev fund donation feature stays
        // disabled by default; see wallet/staking.cpp isDevFundEnabled).
        vDevFundAddress = {};
    }
};

/**
 * Testnet (v1): public test network which is reset from time to time.
 */
class CTestNetParams : public CChainParams {
public:
    CTestNetParams() {
        m_chain_type = ChainType::TESTNET;
        consensus.signet_blocks = false;
        consensus.signet_challenge.clear();
        consensus.nMaxReorganizationDepth = 500;
        consensus.CSVHeight = 0; // CodexaCoin: fresh chain, active from genesis
        consensus.SegwitHeight = 0; // CodexaCoin: fresh chain, active from genesis
        consensus.MinBIP9WarningHeight = 0;
        consensus.powLimit = uint256S("0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimit = uint256S("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimitV2 = uint256S("000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.nTargetTimespan = 16 * 60; // 16 mins
        consensus.nTargetSpacingV1 = 60;
        consensus.nTargetSpacing = 64;
        consensus.fPowAllowMinDifficultyBlocks = true;
        consensus.fPowNoRetargeting = false;
        consensus.fPoSNoRetargeting = false;
        consensus.nRuleChangeActivationThreshold = 11250; // 75% for testchains
        consensus.nMinerConfirmationWindow = 15000; // nTargetTimespan / nTargetSpacing * 1000
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].bit = 28;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].min_activation_height = 0; // No activation delay

        // Deployment of SegWit (BIP141, BIP143, and BIP147)
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].bit = 1;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].min_activation_height = 0; // No activation delay

        // Deployment of Taproot (BIPs 340-342)
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].min_activation_height = 0; // No activation delay

        consensus.nProtocolV1RetargetingFixedTime = 1395631999;
        consensus.nProtocolV2Time = 1407053625;
        consensus.nProtocolV3Time = 1444028400;
        consensus.nProtocolV3_1Time = 1667779200;
        consensus.nLastPOWBlock = 500; // CodexaCoin: founder premine window (mirrors mainnet), see PARAMETERS.md section 5
        consensus.nStakeTimestampMask = 0xf;
        consensus.nCoinbaseMaturity = 10; // Fast maturity for testing; window (500) stays >= this, so no staking-eligibility gap (see PARAMETERS.md section 5.2)

        consensus.nPremineTotal = CAmount{14000000000} * COIN; // CodexaCoin: mirrors mainnet for test parity; testnet coins are worthless
        consensus.nStakeRewardAnnualBP = 1368;
        consensus.nStakeRewardAgeCapSeconds = 60 * 24 * 60 * 60; // 60 days

        consensus.nMinimumChainWork = uint256{};
        consensus.defaultAssumeValid = uint256{};

        pchMessageStart[0] = 0xc1;
        pchMessageStart[1] = 0x02;
        pchMessageStart[2] = 0x7e;
        pchMessageStart[3] = 0x3b;
        nDefaultPort = 26210;
        m_assumed_blockchain_size = 1;

        // CodexaCoin: genesis mined by contrib/genesis/generate_genesis.cpp.
        genesis = CreateGenesisBlock(1785326400, 73100, 0x1f00ffff, 7, 0);
        consensus.hashGenesisBlock = genesis.GetHash();
        assert(consensus.hashGenesisBlock == uint256S("0x719ff8d5c4773340ff014d12c0bbc623aa6fc2abc2b4ecd6dc7e93ef4f609b95"));
        assert(genesis.hashMerkleRoot == uint256S("0x089c9664d716a35a805093b15b0dd6e9f58e84ca21a176c2783a377d23ef6b22"));

        // Note that of those which support the service bits prefix, most only support a subset of
        // possible options.
        // This is fine at runtime as we'll fall back to using them as an addrfetch if they don't support the
        // service bits we want, but we should get them updated to support all service bits wanted by any
        // release ASAP to avoid it where possible.
        // CodexaCoin: TODO placeholders -- see PARAMETERS.md section 9 / Phase 2.
        vSeeds.emplace_back("testnet-seed1.codexacoin.example"); // TODO: stand up real testnet seed node
        vSeeds.emplace_back("testnet-seed2.codexacoin.example"); // TODO: stand up real testnet seed node

        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,111);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,196);
        base58Prefixes[SECRET_KEY] =     std::vector<unsigned char>(1,239);
        base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x35, 0x87, 0xCF};
        base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x35, 0x83, 0x94};

        bech32_hrp = "tcac";

        // CodexaCoin: no fixed-seed IP list exists yet.
        vFixedSeeds.clear();

        fDefaultConsistencyChecks = false;
        m_is_mockable_chain = false;

        // CodexaCoin: fresh chain -- checkpoints reset to genesis only.
        checkpointData = {
            {
                {0, consensus.hashGenesisBlock},
            }
        };

        m_assumeutxo_data = {
            // TODO to be specified in a future patch.
        };

        chainTxData = ChainTxData{
            // CodexaCoin: zeroed, no real chain exists yet
            .nTime    = 0,
            .nTxCount = 0,
            .dTxRate  = 0,
        };

        // CodexaCoin: no dev fund address generated yet -- TODO before testnet launch.
        vDevFundAddress = {};
    }
};

/**
 * Signet: test network with an additional consensus parameter (see BIP325).
 */
class SigNetParams : public CChainParams {
public:
    explicit SigNetParams(const SigNetOptions& options)
    {
        std::vector<uint8_t> bin;
        vSeeds.clear();

        if (!options.challenge) {
            bin = ParseHex("512103ad5e0edad18cb1f0fc0d28a3d4f1f3e445640337489abb10404f2d1e086be430210359ef5021964fe22d6f8e05b2463c9540ce96883fe3b278760f048f5189f2e6c452ae");
 
            /*
            vSeeds.emplace_back("seed.signet.bitcoin.sprovoost.nl.");

            // Hardcoded nodes can be removed once there are more DNS seeds
            vSeeds.emplace_back("178.128.221.177");
            vSeeds.emplace_back("v7ajjeirttkbnt32wpy3c6w3emwnfr3fkla7hpxcfokr3ysd3kqtzmqd.onion:38333");
            */

            vSeeds.clear();

            consensus.nMinimumChainWork = uint256S("0x00");
            consensus.defaultAssumeValid = uint256S("0x00");
            m_assumed_blockchain_size = 1;
            chainTxData = ChainTxData{
                // Data from RPC: getchaintxstats 4096 000000187d4440e5bff91488b700a140441e089a8aaea707414982460edbfe54
                .nTime    = 0,
                .nTxCount = 0,
                .dTxRate  = 0.0,
            };
        } else {
            bin = *options.challenge;
            consensus.nMinimumChainWork = uint256{};
            consensus.defaultAssumeValid = uint256{};
            m_assumed_blockchain_size = 0;
            chainTxData = ChainTxData{
                0,
                0,
                0,
            };
            LogPrintf("Signet with challenge %s\n", HexStr(bin));
        }

        if (options.seeds) {
            vSeeds = *options.seeds;
        }

        m_chain_type = ChainType::SIGNET;
        consensus.signet_blocks = true;
        consensus.signet_challenge.assign(bin.begin(), bin.end());
        consensus.nMaxReorganizationDepth = 500;
        consensus.CSVHeight = 1;
        consensus.SegwitHeight = 1;
        consensus.nTargetTimespan = 16 * 60; // 16 mins
        consensus.nTargetSpacingV1 = 64;
        consensus.nTargetSpacing = 64;
        consensus.fPowAllowMinDifficultyBlocks = false;
        consensus.fPowNoRetargeting = false;
        consensus.fPoSNoRetargeting = false;
        consensus.nRuleChangeActivationThreshold = 12000; // 80% of 15000
        consensus.nMinerConfirmationWindow = 15000; // nTargetTimespan / nTargetSpacing * 1000
        consensus.MinBIP9WarningHeight = 0;
        consensus.powLimit = uint256S("0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimit = uint256S("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimitV2 = uint256S("000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].bit = 28;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].min_activation_height = 0; // No activation delay

        // Activation of Taproot (BIPs 340-342)
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].min_activation_height = 0; // No activation delay

        consensus.nProtocolV1RetargetingFixedTime = 1707168541;
        consensus.nProtocolV2Time = 1707168542;
        consensus.nProtocolV3Time = 1707168543;
        consensus.nProtocolV3_1Time = 1707168544;
        consensus.nLastPOWBlock = 0x7fffffff; // CodexaCoin: no premine window on signet
        consensus.nStakeTimestampMask = 0xf;
        consensus.nCoinbaseMaturity = 10;

        consensus.nPremineTotal = 0;
        consensus.nStakeRewardAnnualBP = 1368;
        consensus.nStakeRewardAgeCapSeconds = 60 * 24 * 60 * 60; // 60 days

        // message start is defined as the first 4 bytes of the sha256d of the block script
        HashWriter h{};
        h << consensus.signet_challenge;
        uint256 hash = h.GetHash();
        std::copy_n(hash.begin(), 4, pchMessageStart.begin());

        nDefaultPort = 46210;

        // CodexaCoin: genesis mined by contrib/genesis/generate_genesis.cpp.
        // Same (nTime, nBits) as testnet by choice -- not consensus-relevant
        // since magic bytes/ports keep the networks from ever interoperating,
        // but noted in PARAMETERS.md as a minor cosmetic overlap.
        genesis = CreateGenesisBlock(1785326400, 73100, 0x1f00ffff, 7, 0);
        consensus.hashGenesisBlock = genesis.GetHash();
        assert(consensus.hashGenesisBlock == uint256S("0x719ff8d5c4773340ff014d12c0bbc623aa6fc2abc2b4ecd6dc7e93ef4f609b95"));
        assert(genesis.hashMerkleRoot == uint256S("0x089c9664d716a35a805093b15b0dd6e9f58e84ca21a176c2783a377d23ef6b22"));

        vFixedSeeds.clear();

        m_assumeutxo_data = {};

        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,111);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,196);
        base58Prefixes[SECRET_KEY] =     std::vector<unsigned char>(1,239);
        base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x88, 0xB2, 0x1E};
        base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x88, 0xAD, 0xE4};

        bech32_hrp = "tcac";

        fDefaultConsistencyChecks = false;
        m_is_mockable_chain = false;

        vDevFundAddress = {};
    }
};

/**
 * Regression test: intended for private networks only. Has minimal difficulty to ensure that
 * blocks can be found instantly.
 */
class CRegTestParams : public CChainParams
{
public:
    explicit CRegTestParams(const RegTestOptions& opts)
    {
        m_chain_type = ChainType::REGTEST;
        consensus.signet_blocks = false;
        consensus.signet_challenge.clear();
        consensus.nMaxReorganizationDepth = 50;
        consensus.CSVHeight = 1;
        consensus.SegwitHeight = 1;
        consensus.MinBIP9WarningHeight = 0;
        consensus.powLimit = uint256S("7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimit = uint256S("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.posLimitV2 = uint256S("000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff");
        consensus.nTargetTimespan = 16 * 60; // 16 mins
        consensus.nTargetSpacingV1 = 64;
        consensus.nTargetSpacing = 64;
        consensus.fPowAllowMinDifficultyBlocks = true;
        consensus.fPowNoRetargeting = true;
        consensus.fPoSNoRetargeting = true;
        consensus.nRuleChangeActivationThreshold = 120; // 80% for regtest
        consensus.nMinerConfirmationWindow = 150; // Faster than normal for regtest (150 instead of 15000)
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].bit = 28;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nStartTime = 0;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TESTDUMMY].min_activation_height = 0; // No activation delay

        // Deployment of SegWit (BIP141, BIP143, and BIP147)
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].bit = 1;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].nStartTime = Consensus::BIP9Deployment::ALWAYS_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].nTimeout = 0;
        consensus.vDeployments[Consensus::DEPLOYMENT_SEGWIT].min_activation_height = 0; // No activation delay

        // Deployment of Taproot (BIPs 340-342)
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].bit = 2;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nStartTime = Consensus::BIP9Deployment::NEVER_ACTIVE;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].nTimeout = Consensus::BIP9Deployment::NO_TIMEOUT;
        consensus.vDeployments[Consensus::DEPLOYMENT_TAPROOT].min_activation_height = 0; // No activation delay

        consensus.nProtocolV1RetargetingFixedTime = 1395631999;
        consensus.nProtocolV2Time = 1407053625;
        consensus.nProtocolV3Time = 1444028400;
        consensus.nProtocolV3_1Time = 1713938400;
        // CodexaCoin: founder premine window enabled on regtest too (unlike
        // upstream Blackcoin's regtest, which never leaves PoW) so the
        // premine + coin-age PoS reward path can actually be exercised
        // end-to-end in tests. See PARAMETERS.md section 5.
        consensus.nLastPOWBlock = 500;
        consensus.nStakeTimestampMask = 0xf;
        consensus.nCoinbaseMaturity = 10;

        consensus.nPremineTotal = CAmount{14000000000} * COIN;
        consensus.nStakeRewardAnnualBP = 1368;
        consensus.nStakeRewardAgeCapSeconds = 60 * 24 * 60 * 60; // 60 days

        consensus.nMinimumChainWork = uint256{};
        consensus.defaultAssumeValid = uint256{};

        pchMessageStart[0] = 0x17;
        pchMessageStart[1] = 0xe4;
        pchMessageStart[2] = 0xb9;
        pchMessageStart[3] = 0x4c;
        nDefaultPort = 36210;
        m_assumed_blockchain_size = 0;

        for (const auto& [dep, height] : opts.activation_heights) {
            switch (dep) {
            /*
            case Consensus::BuriedDeployment::DEPLOYMENT_SEGWIT:
                consensus.SegwitHeight = int{height};
                break;
            */
            case Consensus::BuriedDeployment::DEPLOYMENT_CSV:
                consensus.CSVHeight = int{height};
                break;
            }
        }

        for (const auto& [deployment_pos, version_bits_params] : opts.version_bits_parameters) {
            consensus.vDeployments[deployment_pos].nStartTime = version_bits_params.start_time;
            consensus.vDeployments[deployment_pos].nTimeout = version_bits_params.timeout;
            consensus.vDeployments[deployment_pos].min_activation_height = version_bits_params.min_activation_height;
        }

        // CodexaCoin: genesis mined by contrib/genesis/generate_genesis.cpp
        // (trivial on regtest's near-maximal powLimit -- nonce=1).
        genesis = CreateGenesisBlock(1785326400, 1, 0x207fffff, 7, 0);
        consensus.hashGenesisBlock = genesis.GetHash();
        assert(consensus.hashGenesisBlock == uint256S("0x66a3b7f4db8f62053c717aab1d5ff9fa8cfed4f7b27f2583b438ee8f4c9c12d1"));
        assert(genesis.hashMerkleRoot == uint256S("0x089c9664d716a35a805093b15b0dd6e9f58e84ca21a176c2783a377d23ef6b22"));

        vFixedSeeds.clear(); //!< Regtest mode doesn't have any fixed seeds.
        vSeeds.clear();
        vSeeds.emplace_back("dummySeed.invalid.");

        fDefaultConsistencyChecks = true;
        m_is_mockable_chain = true;

        checkpointData = {
            {
                {0, consensus.hashGenesisBlock},
            }
        };

        m_assumeutxo_data = {
            // CodexaCoin: Blackcoin's regtest assumeutxo snapshot hashes are
            // meaningless for a different genesis/chain; cleared pending
            // CAC-specific regeneration if assumeutxo functional tests are
            // exercised (test/functional/feature_assumeutxo.py).
        };

        chainTxData = ChainTxData{
            0,
            0,
            0
        };

        base58Prefixes[PUBKEY_ADDRESS] = std::vector<unsigned char>(1,111);
        base58Prefixes[SCRIPT_ADDRESS] = std::vector<unsigned char>(1,196);
        base58Prefixes[SECRET_KEY] = std::vector<unsigned char>(1,239);
        base58Prefixes[EXT_PUBLIC_KEY] = {0x04, 0x88, 0xB2, 0x1E};
        base58Prefixes[EXT_SECRET_KEY] = {0x04, 0x88, 0xAD, 0xE4};

        bech32_hrp = "cacrt";

        vDevFundAddress = {};
    }
};

std::unique_ptr<const CChainParams> CChainParams::SigNet(const SigNetOptions& options)
{
    return std::make_unique<const SigNetParams>(options);
}

std::unique_ptr<const CChainParams> CChainParams::RegTest(const RegTestOptions& options)
{
    return std::make_unique<const CRegTestParams>(options);
}

std::unique_ptr<const CChainParams> CChainParams::Main()
{
    return std::make_unique<const CMainParams>();
}

std::unique_ptr<const CChainParams> CChainParams::TestNet()
{
    return std::make_unique<const CTestNetParams>();
}
