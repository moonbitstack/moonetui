## Changes

## Verification

<!-- The gate, in order. Paste what you actually ran. -->

- [ ] `moon fmt`
- [ ] `moon check --target all --deny-warn`
- [ ] `moon build --target all`
- [ ] `moon test --target all`

**Interface**

<!-- Did `moon info --target all` change any pkg.generated.mbti? If so, say what
     moved: that file is the public interface. -->

**Snapshots**

<!-- Snapshots must read the same on wasm, wasm-gc, js and native. If you updated
     any with `moon test --update`, say why the new output is the correct one. -->

**Drivers**

<!-- A change under driver/ cannot be verified on a machine without that
     terminal. Say which drivers you exercised and which you are leaving to CI. -->
