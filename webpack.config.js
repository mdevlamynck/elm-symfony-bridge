const path = require('path');

module.exports = {
  entry: './src/webpack.js',
  output: {
    path: path.resolve(__dirname, 'dist'),
	filename: 'elm-symfony-bridge.js',
  },
  mode: 'production',
  target: 'node',
  module: {
    rules: [{
      test: /\.elm$/,
      exclude: [/elm-stuff/, /node_modules/],
      use: {
        loader: 'elm-webpack-loader',
        options: {}
      }
    }]
  }
};
