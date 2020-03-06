const chokidar = require('chokidar');
const { execSync } = require('child_process');
const fs = require('fs');
const mkdirp = require('mkdirp');
const path = require('path');
const glob = require('glob');
const ElmWorker = require('../src/Main.elm').Elm.Main;

var options = {};
var transpiler = ElmWorker.init();

function run(bundler) {
    options = {
        watch: bundler.options.watch,
        dev: !bundler.options.production,
        outputFolder: 'public',
        elmRoot: './assets/elm',
        elmVersion: '0.19',
        enableRouting: true,
        urlPrefix: '/index.php',
        enableTranslations: false,
        lang: 'en',
    };

    if (options.watch) {
        const patterns = [
            'src/**/*.php',
            'src/**/*.yaml',
            'src/**/*.yml',
            'src/**/*.xml',
            'config/**/*.yaml',
            'config/**/*.yml',
            'config/**/*.xml',
        ];
        chokidar.watch(patterns, { ignoreInitial: true }).on('all', generate);
    }

    generate('called', 'initial');
}

function generate(event, path) {
    transpileRouting();
    transpileTranslations();
}

function transpileRouting() {
    if (!options.enableRouting) {
        return;
    }

    const content = runSymfonyCommand('debug:router --format=json');

    const elmSubscribtion = function (data) {
        onSuccess("routing", data, function() {
            writeIfChanged(options.elmRoot + '/Routing.elm', data.content);
        });

        transpiler.ports.sendToJs.unsubscribe(elmSubscribtion);
    };

    transpiler.ports.sendToJs.subscribe(elmSubscribtion);
    transpiler.ports.sendToElm.send({
        routing: {
            urlPrefix: options.dev ? options.urlPrefix : '',
            content: content,
            version: options.elmVersion
        }
    });
}

function transpileTranslations() {
    if (!options.enableTranslations) {
        return;
    }

    runSymfonyCommand('bazinga:js-translation:dump ' + options.outputFolder + '/js');

    const files = glob.sync('./' + options.outputFolder + '/js/translations/*/' + options.lang + '.json');
    let remainingTranslations = files.length;

    const elmSubscribtion = function (data) {
        onSuccess("translation", data, function() {
            makeDir(options.elmRoot + '/Trans');
            writeIfChanged(options.elmRoot + '/' + data.file.name, data.file.content);
        });

        remainingTranslations--;
        if (remainingTranslations === 0) {
            transpiler.ports.sendToJs.unsubscribe(elmSubscribtion);
            callback();
        }
    };

    transpiler.ports.sendToJs.subscribe(elmSubscribtion);
    files.map(file => {
        const content = fs.readFileSync(file, 'utf8');
        transpiler.ports.sendToElm.send({
            translation: {
                name: file,
                content: content,
                version: options.elmVersion
            }
        });
    });
}

function makeDir(dir) {
    try {
        mkdirp.sync(dir);
    } catch (err) {
        if (err.code !== 'EEXIST') {
            throw err
        }
    }
}

function writeIfChanged(filePath, content) {
    try {
        const existingContent = fs.readFileSync(filePath, 'utf8');

        if (content !== existingContent) {
            writeFile(filePath, content);
        }
    } catch (err) {
        writeFile(filePath, content);
    }
}

function writeFile(filePath, content) {
    makeDir(path.dirname(filePath));
    fs.writeFileSync(filePath, content);
}

function onSuccess(type, data, callback) {
    if (data.type === type && data.succeeded === true) {
        callback();
    } else if (data.succeeded === true) {
        console.error("Expected " + type + " got " + data.type + ".");
    } else {
        console.error(data.error);
    }
}

function runSymfonyCommand(command) {
    return execSync(
        './bin/console ' + command + ' --env=' + (options.dev ? 'dev' : 'prod'),
        {encoding: 'utf8'}
    );
}

module.exports = run;
