Name:       harbour-starling
Summary:    Starling Bank Sailfish OS client
Version:    1.1.0
Release:    23
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
* Sun Mar 08 2026 Miklos <m@example.invalid> - 0.1.0-1
- Initial package