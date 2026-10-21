# Findr Mobile

A campus lost-and-found mobile app with reports, claims, chat and integrated services.

**Built with:** Flutter · Dart · Firebase · Riverpod

**Subject results:** MBAP: A  
*Subject grades; individual project marks were not supplied.*

[Watch the demonstration](https://youtu.be/EPEnVfJLQjo)

## What it includes

- Final Part 3 app source, assets, platform files, dependency manifests and Firestore rules.
- Firebase authentication, item reporting/claims, chat, maps, notifications and biometric unlock.
- AI matching and a NETS sandbox QR reward demonstration.

## Project status

Final source copied; service configuration and a device build are required. The video has no voiceover. NETS is a sandbox demonstration, not a production escrow service. A complete device test has not been performed.

## Folder guide

| Folder | Contents |
| --- | --- |
| [`src/`](src/) | Original implementation, assets and project configuration |
| [`docs/`](docs/) | Available specifications, proposals, reports, diagrams and project context |

## Run or open

Use a compatible Flutter SDK; `pubspec.yaml` specifies Dart ^3.11.5. Configure your own Firebase project and provider integrations, then run:

```text
cd src
flutter pub get
flutter run
```

The Firebase/Google, Groq and NETS values in the copy use placeholders. Do not embed privileged provider secrets in a public client.

## Supporting documents

| File | Format |
| --- | --- |
| [demo.md](docs/demo.md) | MD |
| [mbap-findr-widget-tree.drawio](docs/design/mbap-findr-widget-tree.drawio) | DRAWIO |
| [project-context.md](docs/project-context.md) | MD |
| [mbap-findr-project-proposal.docx](docs/proposal/mbap-findr-project-proposal.docx) | DOCX |
| [mbap-findr-authentication-report.docx](docs/reports-and-presentations/mbap-findr-authentication-report.docx) | DOCX |
| [mbap-findr-final-presentation.pptx](docs/reports-and-presentations/mbap-findr-final-presentation.pptx) | PPTX |
| [mbap-project-specification.pdf](docs/specifications/mbap-project-specification.pdf) | PDF |

## Notes

API keys and demonstration passwords detected in the portfolio copies use
placeholders. Configure your own services before running integrations. Original
source credits and bundled third-party licences remain with their files.
