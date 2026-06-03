# FAQ

## Does this skill delete files automatically?

No. The intended workflow is audit first, review the proposed cleanup plan, then approve specific actions. It should not silently remove personal files.

## Is it safe for my Windows system?

The skill is designed around conservative cleanup categories and explicit approval. Still, disk cleanup always has risk, so review the plan carefully and keep backups for anything important.

## Does it clean user documents, photos, or downloads?

No by default. The safety model avoids personal data folders unless a user explicitly chooses a supported action and understands the risk.

## Why does the reported reclaimable space differ from Windows Settings?

Windows Settings, Disk Cleanup, package caches, browser caches, and this skill may count categories differently. Treat the estimate as a practical planning number rather than a byte-perfect accounting report.

## Can it fix a full system drive?

It can help find and remove safe cleanup candidates, but a severely full system drive may also need uninstalling large apps, moving media, resizing partitions, or replacing storage.

## What should I include in a bug report?

Include your Windows version, PowerShell version, the preset or command you ran, the audit output, the approval step you used, and any error messages. Remove personal paths or private filenames if needed.
