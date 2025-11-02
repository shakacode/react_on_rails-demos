const { existsSync } = require('fs')
const { resolve } = require('path')

const { env } = require('shakapacker')

const envSpecificConfig = () => {
  const path = resolve(__dirname, `${env.nodeEnv}.js`)
  if (existsSync(path)) {
    console.warn(`Loading ENV specific webpack configuration file ${path}`)
    return require(path)
  } else {
    throw new Error(`Could not find file to load ${path}, based on NODE_ENV`)
  }
}

module.exports = envSpecificConfig()
