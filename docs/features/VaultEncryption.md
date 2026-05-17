# Vault encryption

**Epic:** [E-01](../RoadmapEpics.md#e-01-vault-encryption-v1)  
**ADR:** [ADR-0001 — Local-only architecture](../adr/0001-local-only-architecture.md)  
**Architecture:** [DataModel.md § Vault bundle](../Architecture/DataModel.md)  
**Status:** **Partial** (Phase 1 pass: protocol + pass-through seal; CryptoKit + disk bundle planned)

---

## Summary

OpenWrite stores all note content inside an encrypted **`.openwrite` vault bundle**. Each document is a separate AEAD-sealed `.owdoc` blob; the manifest lists document IDs and crypto parameters but never holds key material. Keys live in the macOS Keychain and are cleared when the vault locks.

This design targets **credible parity with Anytype’s encryption narrative** while staying simpler than space-level E2E sync: one user, one vault, file-level crypto you can back up with Time Machine.

---

## User-visible behavior (target v1)

| Action | Expected behavior |
|--------|-------------------|
| Create vault | User chooses location + passphrase; app derives vault key, stores wrapped key in Keychain |
| Open vault | Passphrase or device key unwraps vault key; manifest + documents decrypt; unlock ≤ 2s on Apple Silicon (warm Keychain) |
| Edit & save | Plaintext exists only in memory; `VaultStore` seals JSON → writes atomically to `documents/{uuid}.owdoc` |
| Lock | Menu / sleep / timeout clears derived keys; UI shows locked state; ciphertext remains on disk |
| Quit & reopen | Round-trip identical `VaultDocument` tree (lossless NDL + properties) |

---

## On-disk layout

```
MyVault.openwrite/
  manifest.json              # version, doc ids, salt, cipher suite (no secrets)
  documents/
    {uuid}.owdoc             # AEAD ciphertext + nonce + tag
  index/                     # encrypted index metadata (E-04+, optional in v1)
```

**Manifest (plaintext)** carries enough metadata to open the vault without decrypting every document first: bundle version, document registry, KDF parameters, per-doc content hashes for integrity checks.

---

## Crypto design

| Element | Choice |
|---------|--------|
| AEAD | ChaCha20-Poly1305 or AES-GCM via **CryptoKit** |
| KDF | PBKDF2 or HKDF from passphrase + per-vault salt (manifest) |
| Key storage | Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` baseline) |
| AAD | Document UUID (binds ciphertext to logical doc) |

**Phase 1 pass (current):** `EncryptionService` protocol + `NoOpEncryptionService` pass-through in `VaultStore.sealedPayload(for:)`. In-memory documents only; no bundle path on disk.

---

## Swift modules

| Path | Role |
|------|------|
| `Core/Crypto/EncryptionService.swift` | Protocol, `NoOpEncryptionService`, future `CryptoKitEncryptionService` |
| `Core/Vault/VaultStore.swift` | Registry, seal/open, save hooks |
| `Models/VaultDocument.swift` | Codable document envelope |
| `App/OpenWriteApp.swift` | Lock lifecycle hooks |
| `UI/ContentView.swift` | Create / open / lock UI |

---

## Acceptance criteria (E-01)

- [ ] User creates vault with passphrase; key material only in Keychain after unlock
- [ ] `manifest.json` plaintext; each `.owdoc` is AEAD-encrypted
- [ ] Edit → save → quit → reopen → identical document tree
- [ ] Lock clears derived keys; reopen requires passphrase (Touch ID stretch goal)
- [ ] Cold open ≤ 2s with warm Keychain on M-series Mac

---

## Threat model (pragmatic)

| Threat | Mitigation |
|--------|------------|
| Disk theft / backup leak | AEAD on every `.owdoc` |
| Casual shoulder-surfing after lock | Keys cleared from memory |
| Malware on same user session | Same as any local app — not a HSM; document in master plan |
| Cloud sync (v2) | Encrypt before upload; keys never leave device by default |

Full product stance: [ProductPhilosophy.md](../ProductPhilosophy.md), [OpenWriteMasterPlan.md § Privacy](../OpenWriteMasterPlan.md).

---

## Competitor comparison

| Product | Approach | OpenWrite stance |
|---------|----------|------------------|
| Anytype | E2E spaces, object encryption | Match **story** with file-level vault; skip P2P mesh in v1 |
| Obsidian | Optional community encryption plugins | **Built-in**, no plugin required |
| Reor | Plain Markdown folder | Strict upgrade: MD export only, not master storage |
| Logseq | Local SQLite + optional sync | Encrypted bundle instead of raw `pages/` tree |

---

## Pass 1 absorption

| Absorbed in pass 1 | Still missing |
|--------------------|---------------|
| `EncryptionService` protocol | `CryptoKitEncryptionService` |
| `VaultStore.sealedPayload` encode path | Real `.openwrite` directory I/O |
| `VaultDocument` model | Unlock UI, Keychain wrap |
| Threat model in docs | Lock-on-sleep, integrity verification |

---

## Related

- [FeatureParityMatrix.md § Privacy](../FeatureParityMatrix.md#11-privacy--security)
- [ImportExport.md](./ImportExport.md) — import must target encrypted blobs (E-07 after E-01)
