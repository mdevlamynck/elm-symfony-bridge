const path = require('path');

module.exports = {
  mode: 'production',
  entry: './src/webpack.js',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'elm-symfony-bridge.js',
    library: 'elm-symfony-bridge',
    libraryTarget: 'umd'
  },
  target: 'node',
  module: {
    rules: [{
      test: /\.elm$/,
      exclude: [/elm-stuff/, /node_modules/],
      use: {
        loader: 'elm-webpack-loader',
        options: {
          optimize: true
        }
      }
    }]
  }
};
