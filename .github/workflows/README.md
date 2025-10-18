# GitHub Actions Workflows

## Build and Deploy

This workflow automatically:
- ✅ Builds Android APK (release mode)
- ✅ Builds Web version (release mode)
- ✅ Deploys to GitHub Pages
- ✅ Uploads APK as artifact (downloadable from Actions tab)

### Setup Instructions

1. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Under "Build and deployment"
   - Source: Select **GitHub Actions**

2. **Push to main/master branch:**
   - Workflow triggers automatically on every push
   - Or manually via Actions tab → "Build and Deploy" → "Run workflow"

3. **Access your builds:**
   - **Web app**: https://walking-octopus.github.io/load_schedule/
   - **APK download**: Actions tab → Latest workflow run → Artifacts

### Workflow Details

- **Trigger**: Push to main or master branch, or manual dispatch
- **APK retention**: 30 days
- **Caching**: Flutter SDK and dependencies cached for faster builds
- **Code quality**: Runs `flutter analyze` before building
