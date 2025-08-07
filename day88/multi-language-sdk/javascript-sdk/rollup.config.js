import typescript from '@rollup/plugin-typescript';
import { nodeResolve } from '@rollup/plugin-node-resolve';

export default {
    input: 'src/index.ts',
    output: [
        {
            file: 'dist/index.js',
            format: 'cjs',
            sourcemap: true
        },
        {
            file: 'dist/index.esm.js',
            format: 'es',
            sourcemap: true
        }
    ],
    plugins: [
        nodeResolve(),
        typescript({
            declaration: true,
            declarationDir: 'dist',
            rootDir: 'src'
        })
    ],
    external: ['ws', 'node-fetch']
};
