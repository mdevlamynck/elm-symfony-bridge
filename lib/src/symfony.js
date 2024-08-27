import fs from './filesystem.js';
import { execSync } from 'child_process';

function runCommand(command, options) {
    const consoleBinPath = fs.resolve('bin/console', options);

    return execSync(
        consoleBinPath + ' ' + command + ' --env=' + (options.dev ? 'dev' : 'prod'),
        { encoding: 'utf8', stdio: [] }
    );
}

function queryConfig(configKey, options) {
    const conf = JSON.parse(runCommand(`debug:container --parameter=${configKey} --format=json`, options));

    return conf[configKey] || null;
}

function hasBazingaJsTranslationBundle(options) {
    try {
        runCommand('debug:container bazinga.jstranslation.dump_command --format=json', options);
        return true;
    } catch (e) {
        return false;
    }
}

function queryRouting(options) {
    return fixPhpJsonSerialization(runCommand('debug:router --format=json', options));
}

function dumpTranslations(options) {
    runCommand('bazinga:js-translation:dump ' + options.outputFolder, options);
}

function fixPhpJsonSerialization(content) {
    return content.startsWith('{')
        ? content
        : '{}';
}

module.exports = {
    runCommand,
    queryConfig,
    hasBazingaJsTranslationBundle,
    queryRouting,
    dumpTranslations,
};
