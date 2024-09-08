import { ElmWorker, config, data, fs, generate } from 'elm-symfony-bridge-lib';
import picomatch from 'picomatch';

const isElm = (id) => {
    const parsedId = new URL(id, 'file://');
    const pathname = parsedId.pathname;
    return pathname.endsWith('.elm') && !parsedId.searchParams.has('raw');
}

module.exports = function (userConfig) {
    let global = {
        transpiler: ElmWorker.Elm.Main.init(),
        options: {},
    };
    let hmrPatterns = [];

    return {
        name: 'vite-plugin-elm-symfony-bridge',

        buildStart (options) {
            global.options = data.overrideDefaultsIfProvided(userConfig || {}, {
                watch: this.meta.watchMode,
                dev: process.env.NODE_ENV !== 'production',
                projectRoot: './',
                elmRoot: './assets/elm',
                outputFolder: './elm-stuff/generated-code/elm-symfony-bridge',
                elmVersion: '0.19',
                enableRouting: true,
                urlPrefix: '/index.php',
                enableTranslations: true,
                lang: 'fr',
                watchFolders: ['src', 'config', 'translations'],
                watchExtensions: ['php', 'yaml', 'yml', 'xml'],
                envVariables: {},
            });

            config.loadEnvVariables(global);

            hmrPatterns = data.combinations(
                global.options.watchFolders,
                global.options.watchExtensions,
                (folder, extension) => picomatch(fs.resolve(folder, global.options) + '/**/*.' + extension)
            );
        },

        load: {
            order: 'pre',
            async handler(id) {
                if (!isElm(id)) {
                    return null;
                }

                await generate(global);

                return null;
            }
        },

        async handleHotUpdate (ctx) {
            if (data.arrayAny(hmrPatterns, (isMatch) => isMatch(ctx.file))) {
                await generate(global);
            }

            return ctx.modules;
        },
    }
}
