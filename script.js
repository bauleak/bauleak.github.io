const PROXY_WORKER_URL = "https://cors.cepu.workers.dev/proxy";
// const PROXY_WORKER_URL = "https://cors.kailakece.deno.net/proxy";

let playlist = [];
let filteredPlaylist = [];

// Instance global
let plyrInstance = null;
let shakaPlayerInstance = null;
let hlsInstance = null;

let currentActiveIndex = 0;
let currentEpisodeIndex = 0;
let currentServerIndex = 0;
let currentCategory = "ALL";
let isUserInteracted = false;

const plyrDefaultControls = [
    'play-large', 'play', 'progress', 'current-time', 'duration', 'mute', 'captions', 'settings', 'pip', 'fullscreen'
];

const plyrShakaControls = [
    'play-large', 'play', 'mute', 'captions', 'settings', 'pip', 'fullscreen'
];

async function fetchExternalPlaylist() {
    try {
        const response = await fetch('assets/playlist.json');
        if (!response.ok) throw new Error('Respon file bermasalah.');
        playlist = await response.json();
        
        renderCategoryTabs();
        filterChannels(); 

        setTimeout(() => {
            document.getElementById('videoWrapper').innerHTML = `<img id="player-placeholder" src="assets/banner.png" style="width:100%;height:100%;object-fit:contain;background:#000;display:block;">`;
        }, 300);

        const unmuteOnInteraction = () => {
            isUserInteracted = true;
            if (plyrInstance) plyrInstance.muted = false;
            document.removeEventListener('click', unmuteOnInteraction);
            document.removeEventListener('touchstart', unmuteOnInteraction);
        };
        document.addEventListener('click', unmuteOnInteraction);
        document.addEventListener('touchstart', unmuteOnInteraction);

    } catch (error) {
        console.error("Gagal memuat playlist.json:", error);
        document.getElementById('videoWrapper').innerHTML = 
            `<div style="text-align:center; color:#ff3b30; padding:20px;">Gagal memuat playlist.json</div>`;
    }
}

document.addEventListener('DOMContentLoaded', () => {
    fetchExternalPlaylist();
    initOrientationHandler();
});

window.addEventListener('resize', renderCategoryTabs);

// --- ENGINE PEMBUAT KATEGORI RESPONSIF ---
function renderCategoryTabs() {
    const categories = ["ALL", "LIVE", "FILM", "SEMI", "SERIES", "ANIME", "SHORTS"];
    const tabContainer = document.getElementById('categoryContainer');
    if (!tabContainer) return;

    const isPortrait = window.matchMedia("(orientation: portrait)").matches;

    tabContainer.innerHTML = "";

    if (isPortrait) {
        const select = document.createElement('select');
        select.className = 'category-select';
        select.onchange = (e) => {
            currentCategory = e.target.value;
            filterChannels();
        };

        categories.forEach(cat => {
            const opt = document.createElement('option');
            opt.value = cat;
            opt.innerText = cat;
            if (cat === currentCategory) opt.selected = true;
            select.appendChild(opt);
        });
        tabContainer.appendChild(select);
    } else {
        categories.forEach(cat => {
            const btn = document.createElement('button');
            btn.className = `category-btn ${cat === currentCategory ? 'active' : ''}`;
            btn.innerText = cat;
            btn.onclick = () => {
                currentCategory = cat;
                document.querySelectorAll('.category-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                filterChannels();
            };
            tabContainer.appendChild(btn);
        });
    }
}

function toggleMobileSearch() {
    const searchContainer = document.getElementById('searchContainer');
    if (searchContainer) {
        searchContainer.classList.toggle('active');
        if (searchContainer.classList.contains('active')) {
            setTimeout(() => {
                document.getElementById('searchChannel').focus();
            }, 100);
        } else {
            document.getElementById('searchChannel').value = "";
            filterChannels();
        }
    }
}

function filterChannels() {
    const keyword = document.getElementById('searchChannel').value.toLowerCase();
    
    filteredPlaylist = playlist.filter(item => {
        const matchKeyword = item.title.toLowerCase().includes(keyword);
        const matchCategory = (currentCategory === "ALL") || 
                              (item.category && item.category.toUpperCase() === currentCategory) ||
                              (item.category && item.category.toUpperCase() === "ALL");
                              
        return matchKeyword && matchCategory;
    });

    initPlaylist(filteredPlaylist);
}

function initPlaylist(data) {
    const container = document.getElementById('playlistContainer');
    container.innerHTML = "";
    if(!data || data.length === 0) {
        container.innerHTML = `<div style="grid-column: span 2; text-align:center; color:var(--text-muted); font-size:12px; margin-top:20px;">Channel tidak ditemukan</div>`;
        return;
    }
    data.forEach((item, index) => {
        const isSeries = (item.category === "SERIES" || item.category === "ANIME" || item.category === "SHORTS") && item.episodes;
        let totalServers = 0;
        if (isSeries && item.episodes[0]) {
            totalServers = item.episodes[0].url ? item.episodes[0].url.length : 1;
        } else {
            totalServers = Array.isArray(item.url) ? item.url.length : 1;
        }

        const div = document.createElement('div');
        div.className = `playlist-item`;
        div.setAttribute('onclick', `changeVideo(${index}, this)`);
        div.innerHTML = `
            <div class="item-name">${item.title}</div>
            <div class="item-type">${item.category || 'LIVE'} ${isSeries ? `(${item.episodes.length} Eps)` : `(${totalServers} Svr)`}</div>
        `;
        container.appendChild(div);
    });
}

function changeVideo(filteredIndex, element) {
    document.querySelectorAll('.playlist-item').forEach(el => el.classList.remove('active'));
    if(element) element.classList.add('active');
    
    currentEpisodeIndex = 0; 
    currentServerIndex = 0; 
    playVideo(filteredIndex);
}

// --- CONTROLLER SELEKTOR (SERVER & EPISODE) ---
async function playVideo(index) {
    if(!filteredPlaylist || filteredPlaylist.length === 0 || !filteredPlaylist[index]) return;
    currentActiveIndex = index;
    const item = filteredPlaylist[index];

    const epSelector = document.getElementById('episodeSelector');
    const srvSelector = document.getElementById('serverSelector');
    const isSeries = (item.category === "SERIES" || item.category === "ANIME" || item.category === "SHORTS") && item.episodes && item.episodes.length > 0;

    if (isSeries) {
        epSelector.innerHTML = "";
        item.episodes.forEach((ep, epIdx) => {
            const opt = document.createElement('option');
            opt.value = epIdx;
            let rawName = ep.epName ? String(ep.epName).trim() : "";
            opt.innerText = /^\d+$/.test(rawName) ? `Episode ${rawName}` : (rawName || `Episode ${epIdx + 1}`);
            epSelector.appendChild(opt);
        });
        epSelector.value = currentEpisodeIndex;
        epSelector.style.display = "inline-block";
    } else {
        epSelector.style.display = "none";
    }

    let urlData = isSeries ? item.episodes[currentEpisodeIndex].url : item.url;

    if (Array.isArray(urlData)) {
        srvSelector.innerHTML = "";
        urlData.forEach((srv, sIdx) => {
            const opt = document.createElement('option');
            opt.value = sIdx;
            opt.innerText = srv.serverName || `Server ${sIdx + 1}`;
            srvSelector.appendChild(opt);
        });
        srvSelector.value = currentServerIndex;
        srvSelector.style.display = "inline-block";
    } else {
        srvSelector.style.display = "none";
    }

    executeCorePlay();
}

function switchEpisode() {
    currentEpisodeIndex = parseInt(document.getElementById('episodeSelector').value);
    currentServerIndex = 0; 
    playVideo(currentActiveIndex);
}

function switchServer() {
    currentServerIndex = parseInt(document.getElementById('serverSelector').value);
    executeCorePlay();
}

function nextEpisodeOrChannel() {
    if (!filteredPlaylist.length) return;
    const item = filteredPlaylist[currentActiveIndex];
    const isSeries = (item && (item.category === "SERIES" || item.category === "ANIME" || item.category === "SHORTS") && item.episodes && item.episodes.length > 0);

    if (isSeries && (currentEpisodeIndex + 1 < item.episodes.length)) {
        currentEpisodeIndex++;
        currentServerIndex = 0;
        playVideo(currentActiveIndex);
    } else {
        nextChannel();
    }
}

function prevEpisodeOrChannel() {
    if (!filteredPlaylist.length) return;
    const item = filteredPlaylist[currentActiveIndex];
    const isSeries = (item && (item.category === "SERIES" || item.category === "ANIME" || item.category === "SHORTS") && item.episodes && item.episodes.length > 0);

    if (isSeries && (currentEpisodeIndex - 1 >= 0)) {
        currentEpisodeIndex--;
        currentServerIndex = 0;
        playVideo(currentActiveIndex);
    } else {
        let prevIndex = (currentActiveIndex - 1 + filteredPlaylist.length) % filteredPlaylist.length;
        const prevItem = filteredPlaylist[prevIndex];
        const isPrevSeries = (prevItem && (prevItem.category === "SERIES" || prevItem.category === "ANIME" || prevItem.category === "SHORTS") && prevItem.episodes && prevItem.episodes.length > 0);
        
        currentServerIndex = 0;
        if (isPrevSeries) {
            currentEpisodeIndex = prevItem.episodes.length - 1; // Mulai dari episode terakhir channel sebelumnya
        } else {
            currentEpisodeIndex = 0;
        }
        playVideo(prevIndex);
        updateActivePlaylistItem(prevIndex);
    }
}

function toggleQris(show) {
    const overlay = document.getElementById('qrisOverlay');
    if (show) overlay.classList.add('show');
    else overlay.classList.remove('show');
}

function moveToNextServer() {
    const item = filteredPlaylist[currentActiveIndex];
    if (!item) return;

    const isSeries = (item.category === "SERIES" || item.category === "ANIME" || item.category === "SHORTS") && item.episodes && item.episodes.length > 0;

    if (isSeries) {
        let currentEpisodeData = item.episodes[currentEpisodeIndex];
        let totalServers = Array.isArray(currentEpisodeData.url) ? currentEpisodeData.url.length : 1;

        if (currentServerIndex + 1 < totalServers) {
            currentServerIndex++;
        } else {
            currentServerIndex = 0;
            currentEpisodeIndex = (currentEpisodeIndex + 1) % item.episodes.length;
            const epSelector = document.getElementById('episodeSelector');
            if (epSelector) epSelector.value = currentEpisodeIndex;
        }
        playVideo(currentActiveIndex);
    } else {
        let currentTarget = item.url;
        if (Array.isArray(currentTarget) && currentTarget.length > 1) {
            currentServerIndex = (currentServerIndex + 1) % currentTarget.length;
            const srvSelector = document.getElementById('serverSelector');
            if (srvSelector) srvSelector.value = currentServerIndex;
            executeCorePlay();
        }
    }
}

// --- ENGINE PEMUTAR VIDEO CORE ---
async function executeCorePlay() {
    const item = filteredPlaylist[currentActiveIndex];
    const wrapper = document.getElementById('videoWrapper');
    const mainLayout = document.querySelector('.main-layout');
    
    await resetAllPlayers();
    wrapper.innerHTML = "";
    
    if (!item) return;
    
    const closeBtn = document.querySelector('.close-player-btn');
    if (closeBtn) closeBtn.style.display = 'flex'; 

    const prevBtn = document.getElementById('prevButton');
    const nextBtn = document.getElementById('nextButton');
    if (prevBtn && nextBtn) {
    	const isPortrait = window.matchMedia("(orientation: portrait)").matches;
        if (item.category && item.category.toUpperCase() === "SHORTS" && isPortrait) {
            prevBtn.style.display = 'flex';
            nextBtn.style.display = 'flex';
        } else {
            prevBtn.style.display = 'none';
            nextBtn.style.display = 'none';
        }
    }
    
    if (item.category && item.category.toUpperCase() === "SHORTS") {
        mainLayout.classList.add('shorts-portrait-mode');
    } else {
        mainLayout.classList.remove('shorts-portrait-mode');
    }

    const isSeries = (item.category === "SERIES" || item.category === "ANIME" || item.category === "SHORTS") && item.episodes;
    let currentTarget = isSeries ? item.episodes[currentEpisodeIndex].url : item.url;
    
    let serverObject = Array.isArray(currentTarget) ? currentTarget[currentServerIndex] : { link: currentTarget, type: item.type, drm: item.drm };
    const isLoopActive = (item.loop === "true" || item.loop === true);

    if (!serverObject || !serverObject.link) {
        if (isLoopActive) moveToNextServer();
        else wrapper.innerHTML = `<div style="text-align:center; color:#ff3b30; padding:20px;">Link stream tidak ditemukan.</div>`;
        return;
    }
    
    let activeRawUrl = serverObject.link;
    let finalUrl = activeRawUrl;
    let streamType = serverObject.type || item.type || "direct"; 
    let drmData = serverObject.drm || item.drm || null;

    const referer = serverObject.referer || item.referer;
    const ua = serverObject.ua || item.ua;
    const hasHeaders = !!(referer || ua);

    if (hasHeaders) {
        const proxyParams = new URLSearchParams();
        proxyParams.append('url', activeRawUrl);
        if (referer) proxyParams.append('referer', referer);
        if (ua) proxyParams.append('ua', ua);
        finalUrl = `${PROXY_WORKER_URL}?${proxyParams.toString()}`;
    }

    // ENGINE YOUTUBE
    const youtubeRegex = /(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?|live|shorts)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})/i;
    const isYoutubePlaylist = finalUrl.includes("youtube.com/playlist?list=");
    const matchYoutube = finalUrl.match(youtubeRegex);

    if (matchYoutube || isYoutubePlaylist || streamType === "youtube") {
        if (!window.YT) {
            const tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            const firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
        }

        wrapper.innerHTML = `<div id="ytPlayerContainer" style="width:100%; height:100%;"></div>`;
        
        const videoId = matchYoutube ? matchYoutube[1] : null;
        const listId = isYoutubePlaylist ? new URL(finalUrl).searchParams.get("list") : null;

        const createYTPlayer = () => {
            let playerConfig = {
                height: '100%',
                width: '100%',
                playerVars: {
                    'autoplay': 1,
                    'muted': !isUserInteracted,
                    'controls': 1,
                    'modestbranding': 1,
                    'rel': 0,
                    'showinfo': 0,
                    'iv_load_policy': 3,
                    'disablekb': 1
                },
                events: {
                    'onStateChange': (event) => {
                        if (event.data === window.YT.PlayerState.ENDED) {
                            console.log("[YouTube Engine] Video selesai diputar.");
                            if (currentCategory === "SHORTS" || (item.category && item.category.toUpperCase() === "SHORTS")) {
                                nextEpisodeOrChannel();
                            } 
                            else if (isLoopActive) {
                                moveToNextServer();
                            }
                        }
                    },
                    'onError': (event) => {
                        console.log("[YouTube Engine] Error terdeteksi.");
                        if (currentCategory === "SHORTS" || (item.category && item.category.toUpperCase() === "SHORTS")) {
                            nextEpisodeOrChannel();
                        } else if (isLoopActive) {
                            moveToNextServer();
                        }
                    }
                }
            };

            if (listId) {
                playerConfig.playerVars.listType = 'playlist';
                playerConfig.playerVars.list = listId;
            } else if (videoId) {
                playerConfig.videoId = videoId;
            }

            window.activeYTPlayer = new window.YT.Player('ytPlayerContainer', playerConfig);
        };

        if (window.YT && window.YT.Player) {
            createYTPlayer();
        } else {
            window.onYouTubeIframeAPIReady = createYTPlayer;
        }
        return;
    }
    
    // ENGINE EMBED / IFRAME 
    if (streamType === "embed" || /(\/embed\/|\.html|\.php)/i.test(finalUrl)) {
        wrapper.innerHTML = `<iframe src="${finalUrl}" sandbox="allow-scripts allow-same-origin allow-forms" allow="autoplay; encrypted-media; picture-in-picture" loading="lazy" allowfullscreen style="width:100%; height:100%; border:none; border-radius:8px;"></iframe>`;
        return;
    }

    // STRUKTUR UTAMA ELEMEN <VIDEO>
    const videoMute = isUserInteracted ? "" : "muted";
    wrapper.innerHTML = `<video id="plyrPlayer" class="plyr" playsinline autoplay ${videoMute}></video>`;
    const videoElement = document.getElementById('plyrPlayer');

    const isMpd = finalUrl.includes('.mpd') || streamType === "dash" || streamType === "adaptive-dash";
    const isHls = finalUrl.includes('.m3u8') || streamType === "hls";
    
    // ENGINE SHAKA PLAYER (DASH / MPD)
    if (isMpd || (streamType === "adaptive" && !isHls)) {
        shakaPlayerInstance = new shaka.Player(videoElement);
        
        let shakaConfig = {
            streaming: { 
                rebufferingGoal: 1.5, bufferingGoal: 15, bufferBehind: 10,
                safeUnderflowBuffer: 1, alwaysStreamText: false, ignoreTextStreamFailures: true,
                failureCallback: () => shakaPlayerInstance.retryStreaming() 
            },
            manifest: { 
                dash: { autoCorrectTiming: true, ignoreMinBufferTime: true }, 
                retryParameters: { maxAttempts: 5, baseDelay: 500 } 
            }
        };

        if (drmData) {
            if (drmData.type === "widevine") {
                let licenseUrl = drmData.licenseServer;
                if (hasHeaders) {
                    const licProxy = new URLSearchParams();
                    licProxy.append('url', licenseUrl);
                    if (referer) licProxy.append('referer', referer);
                    if (ua) proxyParams.append('ua', ua);
                    licenseUrl = `${PROXY_WORKER_URL}?${licProxy.toString()}`;
                }
                shakaConfig.drm = { servers: { 'com.widevine.alpha': licenseUrl } };
            } else if (drmData.type === "clearkey") {
                let clearKeysMap = {};
                if (drmData.keys && typeof drmData.keys === 'object') {
                    for (let keyId in drmData.keys) clearKeysMap[keyId.trim()] = drmData.keys[keyId].trim();
                }
                shakaConfig.drm = { clearKeys: clearKeysMap };
            }
        }

        shakaPlayerInstance.configure(shakaConfig);
        
        if (hasHeaders) {
            shakaPlayerInstance.getNetworkingEngine().registerRequestFilter((type, request) => {
                if (referer) request.headers['Referer'] = referer;
                if (ua) request.headers['User-Agent'] = ua;

                const currentUri = request.uris[0];
                if (currentUri.includes(PROXY_WORKER_URL) || currentUri.includes("workers.dev")) return;
                
                const segmentProxy = new URLSearchParams();
                segmentProxy.append('url', currentUri);
                if (referer) segmentProxy.append('referer', referer);
                if (ua) segmentProxy.append('ua', ua);
                
                request.uris[0] = `${PROXY_WORKER_URL}?${segmentProxy.toString()}`;
            });
        }

        try {
            await shakaPlayerInstance.load(finalUrl);

            const variantTracks = shakaPlayerInstance.getVariantTracks();
            const availableQualities = [...new Set(variantTracks.map(track => track.height))]
                                        .filter(height => height !== null)
                                        .sort((a, b) => a - b);
            
            availableQualities.unshift(0);

            plyrInstance = new Plyr(videoElement, { 
                controls: plyrShakaControls,
                autoplay: true,
                quality: {
                    default: 0,
                    options: availableQualities,
                    forced: true,
                    onChange: (selectedQuality) => updateShakaQuality(selectedQuality)
                },
                i18n: { 
                    quality: 'Resolusi',
                    qualityLabel: { 0: 'Auto' }
                }
            });

            if (isLoopActive) {
                videoElement.addEventListener('ended', () => {
                    if (item.category && item.category.toUpperCase() === "SHORTS") {
                        nextEpisodeOrChannel();
                    } else {
                        moveToNextServer();
                    }
                });
            }
        } catch (error) {
            console.error("Shaka Error:", error.code);
            if (isLoopActive) {
                if (item.category && item.category.toUpperCase() === "SHORTS") {
                    nextEpisodeOrChannel();
                } else {
                    moveToNextServer();
                }
            } else {
                wrapper.innerHTML = `<div style="text-align:center; color:#ff3b30; padding:30px;">Playback Error (${error.code})</div>`;
            }
        }
        return;
    }

    // ENGINE HLS.JS (M3U8)
    if (isHls) {
        if (Hls.isSupported()) {
            const hlsConfig = {
                maxBufferSize: 30 * 1024 * 1024,
                maxBufferLength: 30,
                enableWorker: true,
                lowLatencyMode: true
            };

            if (hasHeaders) {
                hlsConfig.xhrSetup = function(xhr, url) {
                    if (!url.startsWith(PROXY_WORKER_URL) && !url.includes("workers.dev")) {
                        const segmentProxy = new URLSearchParams();
                        segmentProxy.append('url', url);
                        if (referer) segmentProxy.append('referer', referer);
                        if (ua) segmentProxy.append('ua', ua);
                        xhr.open('GET', `${PROXY_WORKER_URL}?${segmentProxy.toString()}`, true);
                    }
                };
            }

            hlsInstance = new Hls(hlsConfig);
            hlsInstance.loadSource(finalUrl);
            hlsInstance.attachMedia(videoElement);
            
            hlsInstance.on(Hls.Events.MANIFEST_PARSED, function() {
                const availableQualities = hlsInstance.levels.map((l) => l.height);
                availableQualities.unshift(0); 

                plyrInstance = new Plyr(videoElement, {
                    controls: plyrDefaultControls,
                    autoplay: true,
                    quality: {
                        default: 0,
                        options: availableQualities,
                        forced: true,
                        onChange: (e) => updateHlsQuality(e)
                    },
                    i18n: { 
                        quality: 'Resolusi',
                        qualityLabel: { 0: 'Auto' }
                    }
                });
            });

            if (isLoopActive) {
                videoElement.addEventListener('ended', () => {
                    if (item.category && item.category.toUpperCase() === "SHORTS") {
                        nextEpisodeOrChannel();
                    } else {
                        moveToNextServer();
                    }
                });
            }
            hlsInstance.on(Hls.Events.ERROR, (e, data) => { 
                if (data.fatal && isLoopActive) {
                    if (item.category && item.category.toUpperCase() === "SHORTS") {
                        nextEpisodeOrChannel();
                    } else {
                        moveToNextServer();
                    }
                } 
            });
        } 
        else if (videoElement.canPlayType('application/vnd.apple.mpegurl')) {
            videoElement.src = finalUrl;
            plyrInstance = new Plyr(videoElement, { controls: plyrDefaultControls, autoplay: true });
            if (isLoopActive) {
                videoElement.addEventListener('ended', () => {
                    if (item.category && item.category.toUpperCase() === "SHORTS") {
                        nextEpisodeOrChannel();
                    } else {
                        moveToNextServer();
                    }
                });
            }
        }
        return;
    }

    // ENGINE DIRECT PLAY (MP4 / WEBM / DLL)
    videoElement.src = finalUrl;
    plyrInstance = new Plyr(videoElement, { controls: plyrDefaultControls, autoplay: true });
    
    if (isLoopActive) {
        videoElement.addEventListener('ended', () => {
            if (item.category && item.category.toUpperCase() === "SHORTS") {
                nextEpisodeOrChannel();
            } else {
                moveToNextServer();
            }
        });
    }
    videoElement.addEventListener('error', () => { 
        if (isLoopActive) {
            if (item.category && item.category.toUpperCase() === "SHORTS") {
                nextEpisodeOrChannel();
            } else {
                moveToNextServer();
            }
        } 
    });
}

function updateHlsQuality(newQuality) {
    if (!hlsInstance) return;
    if (newQuality === 0) hlsInstance.currentLevel = -1;
    else {
        hlsInstance.levels.forEach((level, levelIndex) => {
            if (level.height === newQuality) hlsInstance.currentLevel = levelIndex;
        });
    }
}

function updateShakaQuality(newQuality) {
    if (!shakaPlayerInstance) return;
    if (newQuality === 0) {
        shakaPlayerInstance.configure({ streaming: { abr: { enabled: true } } });
    } else {
        shakaPlayerInstance.configure({ streaming: { abr: { enabled: false } } });
        
        const tracks = shakaPlayerInstance.getVariantTracks();
        const matchingTrack = tracks.find(track => track.height === newQuality);
        
        if (matchingTrack) {
            shakaPlayerInstance.selectVariantTrack(matchingTrack, true);
        }
    }
}

function initOrientationHandler() {
    const handleOrientation = () => {
        const isFullscreen = document.fullscreenElement || document.webkitFullscreenElement || document.mozFullScreenElement || document.msFullscreenElement;
        if (isFullscreen) {
            const isMobileOrTablet = /Mobi|Android|iPhone|iPad|iPod|Windows Phone/i.test(navigator.userAgent) || (navigator.maxTouchPoints > 0);
            
            if (screen.orientation && screen.orientation.lock) {
                if (currentCategory === "SHORTS" && isMobileOrTablet) {
                    screen.orientation.lock('portrait').catch(() => {});
                } else {
                    screen.orientation.lock('landscape').catch(() => {});
                }
            }
        } else {
            if (screen.orientation && screen.orientation.unlock) { 
                try { screen.orientation.unlock(); } catch(e){} 
            }
        }

        const item = filteredPlaylist[currentActiveIndex];
        const prevBtn = document.getElementById('prevButton');
        const nextBtn = document.getElementById('nextButton');
        
        const isVideoPlaying = document.querySelector('.close-player-btn') && document.querySelector('.close-player-btn').style.display === 'flex';

        if (prevBtn && nextBtn && item && isVideoPlaying) {
            const isPortrait = window.matchMedia("(orientation: portrait)").matches;
            
            if (item.category && item.category.toUpperCase() === "SHORTS" && isPortrait) {
                prevBtn.style.display = 'flex';
                nextBtn.style.display = 'flex';
            } else {
                prevBtn.style.display = 'none';
                nextBtn.style.display = 'none';
            }
        }
    };

    document.addEventListener('fullscreenchange', handleOrientation);
    document.addEventListener('webkitfullscreenchange', handleOrientation);
    document.addEventListener('mozfullscreenchange', handleOrientation);
    document.addEventListener('MSFullscreenChange', handleOrientation);

    window.matchMedia("(orientation: portrait)").addEventListener("change", handleOrientation);
}

async function resetAllPlayers() {
    if (window.activeYTPlayer && window.activeYTPlayer.destroy) { try { window.activeYTPlayer.destroy(); } catch(e){} window.activeYTPlayer = null; }
    if (plyrInstance) { try { plyrInstance.destroy(); } catch (e) {} plyrInstance = null; }
    if (hlsInstance) { try { hlsInstance.destroy(); } catch (e) {} hlsInstance = null; }
    if (shakaPlayerInstance) { try { await shakaPlayerInstance.destroy(); } catch (e) {} shakaPlayerInstance = null; }
}

async function closePlayer() {
    await resetAllPlayers();
    document.querySelector('.main-layout').classList.remove('shorts-portrait-mode');
    document.getElementById('videoWrapper').innerHTML = `<img id="player-placeholder" src="assets/banner.png" style="width:100%;height:100%;object-fit:contain;background:#000;display:block;">`;
    document.getElementById('serverSelector').style.display = "none";
    document.getElementById('episodeSelector').style.display = "none";
    const closeBtn = document.querySelector('.close-player-btn');
    if (closeBtn) closeBtn.style.display = 'none';
    const prevBtn = document.getElementById('prevButton');
    if (prevBtn) prevBtn.style.display = 'none';
    const nextBtn = document.getElementById('nextButton');
    if (nextBtn) nextBtn.style.display = 'none';
    document.querySelectorAll('.playlist-item').forEach(el => el.classList.remove('active'));
}

function nextChannel() {
    if (!filteredPlaylist.length) return;
    let nextIndex = (currentActiveIndex + 1) % filteredPlaylist.length;
    currentEpisodeIndex = 0;
    currentServerIndex = 0;
    playVideo(nextIndex);
    updateActivePlaylistItem(nextIndex);
}

function prevChannel() {
    if (!filteredPlaylist.length) return;
    let prevIndex = (currentActiveIndex - 1 + filteredPlaylist.length) % filteredPlaylist.length;
    currentEpisodeIndex = 0;
    currentServerIndex = 0;
    playVideo(prevIndex);
    updateActivePlaylistItem(prevIndex);
}

function updateActivePlaylistItem(index) {
    document.querySelectorAll('.playlist-item').forEach(el => el.classList.remove('active'));
    const el = document.querySelectorAll('.playlist-item')[index];
    if (el) el.classList.add('active');
}

let touchStartY = 0;
document.getElementById('videoWrapper').addEventListener('touchstart', e => {
    if (currentCategory !== "SHORTS") return;
    touchStartY = e.touches[0].clientY;
});

document.getElementById('videoWrapper').addEventListener('touchend', e => {
    if (currentCategory !== "SHORTS") return;
    let dy = e.changedTouches[0].clientY - touchStartY;
    if (dy < -60) nextEpisodeOrChannel();
    if (dy > 60) prevEpisodeOrChannel();
});