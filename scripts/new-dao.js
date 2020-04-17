const GardensTemplate = artifacts.require("GardensTemplate")
const Token = artifacts.require("Token")

const DAO_ID = "05" // Note this must be unique for each deployment, change it for subsequent deployments
const INITIAL_SUPERVISOR = "0xb4124cEB3451635DAcedd11767f004d8a28c6eE7"
const NETWORK_ARG = "--network"
const DAO_ID_ARG = "--daoid"

const argValue = (arg, defaultValue) => process.argv.includes(arg) ? process.argv[process.argv.indexOf(arg) + 1] : defaultValue

const network = () => argValue(NETWORK_ARG, "local")
const daoId = () => argValue(DAO_ID_ARG, DAO_ID)

const gardensTemplateAddress = () => {
  if (network() === "rinkeby") {
    const Arapp = require("../arapp")
    return Arapp.environments.rinkeby.address
  } else if (network() === "mainnet") {
    const Arapp = require("../arapp")
    return Arapp.environments.mainnet.address
  } else {
    const Arapp = require("../arapp_local")
    return Arapp.environments.devnet.address
  }
}
const ORG_TOKEN_NAME = "OrgToken"
const ORG_TOKEN_SYMBOL = "OGT"
const SUPPORT_REQUIRED = 50e16 // 50%
const MIN_ACCEPTANCE_QUORUM = 20e16 // 20%
const VOTE_DURATION_BLOCKS = 15
const VOTE_BUFFER_BLOCKS = 10
const VOTE_EXECUTION_DELAY_BLOCKS = 5
const VOTING_SETTINGS = [SUPPORT_REQUIRED, MIN_ACCEPTANCE_QUORUM, VOTE_DURATION_BLOCKS, VOTE_BUFFER_BLOCKS, VOTE_EXECUTION_DELAY_BLOCKS]
const USE_AGENT_AS_VAULT = false

const TOLLGATE_FEE = 1e18 // 1 DAI
const USE_CONVICTION_AS_FINANCE = true
const FINANCE_PERIOD = 0 // Irrelevant if using conviction as finance

module.exports = async (callback) => {
  try {
    const gardensTemplate = await GardensTemplate.at(gardensTemplateAddress())

    const tollgateToken = await Token.new(INITIAL_SUPERVISOR, "Honey", "HNY")
    console.log(`Created HNY Token: ${tollgateToken.address}`)

    const convictionVotingRequestToken = await Token.new(INITIAL_SUPERVISOR, "DAI", "DAI")
    console.log(`Created DAI Token: ${convictionVotingRequestToken.address}`)

    const createDaoTxOneReceipt = await gardensTemplate.createDaoTxOne(
      ORG_TOKEN_NAME,
      ORG_TOKEN_SYMBOL,
      [INITIAL_SUPERVISOR],
      VOTING_SETTINGS,
      USE_AGENT_AS_VAULT
    );
    // console.log(`DEBUG: ${createDaoTxOneReceipt.logs.find(x => x.event === "DEBUG")} `)
    console.log(`Tx One Complete. DAO address: ${createDaoTxOneReceipt.logs.find(x => x.event === "DeployDao").args.dao} Gas used: ${createDaoTxOneReceipt.receipt.gasUsed} `)

    const createDaoTxTwoReceipt = await gardensTemplate.createDaoTxTwo(
      daoId(),
      tollgateToken.address,
      TOLLGATE_FEE,
      USE_CONVICTION_AS_FINANCE,
      convictionVotingRequestToken.address,
      FINANCE_PERIOD
    )
    console.log(`Tx Two Complete. Gas used: ${createDaoTxTwoReceipt.receipt.gasUsed} `)


  } catch (error) {
    console.log(error)
  }
  callback()
}
