import fs from './filesystem.js';
import { exec } from 'child_process';

async function runCommand(command, options) {
    const consoleBinPath = fs.resolve('bin/console', options);

    return new Promise((resolve, reject) => {
        exec(
            consoleBinPath + ' ' + command + ' --env=' + (options.dev ? 'dev' : 'prod'),
            { encoding: 'utf8' },
            (err, stdout, stderr) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(stdout);
                }
            }
        );
    });
}

async function queryConfig(configKey, options) {
    const conf = JSON.parse(await runCommand(`debug:container --parameter=${configKey} --format=json`, options));

    return conf[configKey] || null;
}

async function hasBazingaJsTranslationBundle(options) {
    try {
        await runCommand('debug:container bazinga.jstranslation.dump_command --format=json', options);
        return true;
    } catch (e) {
        return false;
    }
}

async function queryRouting(options) {
    return fixPhpJsonSerialization(await runCommand('debug:router --format=json', options));
}

async function dumpTranslations(options) {
    await runCommand('bazinga:js-translation:dump ' + options.outputFolder, options);
}

function fixPhpJsonSerialization(content) {
    return content.startsWith('{')
        ? content
        : '{}';
}

module.exports = {
    queryConfig,
    hasBazingaJsTranslationBundle,
    queryRouting,
    dumpTranslations,
};
