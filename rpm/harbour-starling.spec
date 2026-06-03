Name:       harbour-starling
Summary:    Starling Bank Sailfish OS client
Version:    1.1.0
Release:    39
License:    MIT
URL:        https://example.invalid/harbour-starling
Source0:    %{name}-%{version}.tar.bz2

BuildRequires:  cmake
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Gui)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(sailfishsecrets)

Requires:       sailfishsilica-qt5

%description
Harbour Starling is a Sailfish OS client for managing your Starling Bank account using Personal Access Tokens.

%prep
%setup -q

%build
%cmake
%cmake_build

%install
%cmake_install

%files
%license
%doc
%{_bindir}/harbour-starling
%{_datadir}/applications/harbour-starling.desktop
%{_datadir}/icons/hicolor/172x172/apps/harbour-starling.png
%{_datadir}/harbour-starling/qml
%{_datadir}/harbour-starling/qml/pages
%{_datadir}/harbour-starling/qml/cover

%changelog
* Sun Mar 08 2026 edp17 <edp17@protonmail.com> - 1.0.0-1
- Initial package
* Wed Jun 03 2026 edp17 <edp17@protonmail.com> - 1.1.0-1
New features:
- Transaction export to CSV
- Custom transaction date range filter
- Transaction notes and category editing
- Transaction attachments upload/download with file picker
- Regular Payments: Direct Debits and Standing Orders with details/history
- Savings Goals/Spaces: create, add/withdraw money, delete
- Round-up support: view, enable and disable
- Payee account scheduled payments and payment history
- Account holder email/address update
- Profile image display/update/delete

Improvements:
- Cleaner card-based UI across detail pages
- Better offline/stored card handling
- Safer PIN-gated sensitive actions
- Improved empty/loading states
- Reduced noisy console output for expected optional API responses