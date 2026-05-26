import React, { useEffect, useState } from "react";
import { debugData } from "../utils/debugData";
import Menu from "./Menu";
import { useSelector, useDispatch } from "react-redux";
import { RootState } from "../store";
import PublicSquads from "./PublicSquads";
import Members from "./Members";
import Settings from "./Settings";
import Create from "./Create";
import ChatBox from "./ChatBox";
import Hud from "./Hud";
import Leaderboard from "./Leaderboard";
import WarBanner from "./WarBanner";
import WarChallenge from "./WarChallenge";
import WarResult from "./WarResult";
import WarTargets from "./WarTargets";
import WarBetting from "./WarBetting";
import { setCurrentMenu, setSquadId, setPlayerId, setPersonalSettings, setTheme, setWar, setWarBetting, setMyBet, updateWarScore, clearWar } from "../slices/globalSlice";
import { DndContext, useDraggable, useDroppable } from '@dnd-kit/core';
import { VisibilityProvider } from "../providers/VisibilityProvider";
import ChatNotification from "./ChatNotification";
import { setLocale } from "../slices/localeSlice";

import useKeyPress from "../hooks/useKeyHandler";
import { useNuiEvent } from "../hooks/useNuiEvent";
import { fetchNui } from "../utils/fetchNui";
import { isEnvBrowser } from "../utils/misc";
import { setOwner } from "../slices/globalSlice";
// This will set the NUI to visible if we are
// developing in browser
debugData([
  {
    action: "setVisible",
    data: true,
  },
]);

type ChallengeData = {
  squadId: number;
  name: string;
  image: string;
  members: number;
}

type WarResultData = {
  winner?: { id: number; name: string; score: number };
  loser?: { id: number; name: string; score: number };
  isDraw: boolean;
  squad1?: { id: number; name: string; score: number };
  squad2?: { id: number; name: string; score: number };
  forfeit?: boolean;
}

const App: React.FC = () => {
  const [chatVisible, setChatVisible] = useState(false);
  const [challengeData, setChallengeData] = useState<ChallengeData | null>(null);
  const [warResultData, setWarResultData] = useState<WarResultData | null>(null);
  let { squadId, currentMenu, personal, war } = useSelector((state: RootState) => state.globalSlice);
  const dispatch = useDispatch();

  useNuiEvent('setLocale', (locale: any) => {
    console.log('Setting locale to', JSON.stringify(locale))
    dispatch(setLocale(locale))
  })

  useNuiEvent('squadDeleted', () => {
    setChatVisible(false);
    dispatch(setSquadId(null));
    dispatch(setCurrentMenu("squads"));
    dispatch(clearWar());
  });

  useNuiEvent('kicked', () => {
    setChatVisible(false);
    dispatch(setSquadId(null));
    dispatch(setCurrentMenu("squads"));
    dispatch(clearWar());
  });

  useNuiEvent<ChallengeData>('warChallenge', (data) => {
    setChallengeData(data);
  });

  useNuiEvent('warBettingPhase', (data: any) => {
    setChallengeData(null);
    dispatch(setWarBetting({
      squad1: data.squad1,
      squad2: data.squad2,
      duration: data.duration,
      betWaitTime: data.betWaitTime,
      minBet: data.minBet,
      maxBet: data.maxBet,
    }));
  });

  useNuiEvent('warStarted', (data: any) => {
    setChallengeData(null);
    dispatch(setWar({
      squad1: data.squad1,
      squad2: data.squad2,
      duration: data.duration,
      startTime: data.startTime,
      timeLeft: data.duration,
    }));
  });

  useNuiEvent('warScoreUpdate', (data: any) => {
    dispatch(updateWarScore({
      squad1: data.squad1,
      squad2: data.squad2,
      timeLeft: data.timeLeft,
    }));
  });

  useNuiEvent<WarResultData>('warEnded', (data) => {
    setWarResultData(data);
    dispatch(clearWar());
  });

  useKeyPress("Escape", () => {
    setChatVisible(false);
  });

  // Browser-only mock: test war modals with keyboard shortcuts
  useEffect(() => {
    if (!isEnvBrowser()) return;
    const handler = (e: KeyboardEvent) => {
      // Press "1" to show war challenge modal
      if (e.key === '1') {
        setChallengeData({
          squadId: 999,
          name: 'Shadow Wolves',
          image: 'https://i.pravatar.cc/150?img=15',
          members: 5,
        });
      }
      // Press "2" to start a mock war (shows banner)
      if (e.key === '2') {
        setChallengeData(null);
        dispatch(setWar({
          squad1: { id: 123456, name: 'My Squad', score: 3 },
          squad2: { id: 999, name: 'Shadow Wolves', score: 1 },
          duration: 300,
          startTime: Math.floor(Date.now() / 1000),
          timeLeft: 245,
        }));
      }
      // Press "3" to show war result (victory)
      if (e.key === '3') {
        dispatch(clearWar());
        setWarResultData({
          winner: { id: 123456, name: 'My Squad', score: 7 },
          loser: { id: 999, name: 'Shadow Wolves', score: 3 },
          isDraw: false,
        });
      }
      // Press "4" to show war result (draw)
      if (e.key === '4') {
        dispatch(clearWar());
        setWarResultData({
          isDraw: true,
          squad1: { id: 123456, name: 'My Squad', score: 5 },
          squad2: { id: 999, name: 'Shadow Wolves', score: 5 },
        });
      }
      // Press "5" to show betting phase
      if (e.key === '5') {
        setChallengeData(null);
        dispatch(setWarBetting({
          squad1: { id: 123456, name: 'My Squad', score: 0 },
          squad2: { id: 999, name: 'Shadow Wolves', score: 0 },
          duration: 300,
          betWaitTime: 15,
          minBet: 100,
          maxBet: 10000,
        }));
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, []);

  useEffect(() => {
    // Browser mock: set squadId + owner so we can see members/leaderboard
    if (isEnvBrowser()) {
      dispatch(setSquadId(123456));
      dispatch(setOwner(true));
      dispatch(setPlayerId(1));
      dispatch(setCurrentMenu("members"));
    }

    fetchNui("getPlayerId").then((id) => {
      if (id) {
        dispatch(setPlayerId(id));
      }
    });
    let localSettings = localStorage.getItem('personalSettings')
    const personalSettings = localSettings ? JSON.parse(localSettings) : {
      hudVisible: true,
      nametagsVisible: true,
      blipsVisible: true,
      hudAlignment: "left"
    }
    dispatch(setPersonalSettings(personalSettings))
    fetchNui('setPersonalSettings', personalSettings)

    fetchNui('getTheme', null, {
      'primary': '#FF2F2F',
      'primary-content': '#900000',
      'primary-opacity': 'rgba(255, 47, 47, 0.2)',
      'menu-bg': '#080A0C',
      'menu-item': '#0B1215',
      'menu-darker': '#060A0C',
      'menu-border': '#222e34',
      'menu-divider': '#0A0A0B',
      'danger': '#D22829',
      'success': '#9DDB8D',
      'hud-bg': '#222222',
      'health-label': '#A51B24',
      'health-bar': '#DF202D',
      'armor-bar': '#FFFFFF',
      'chat-header': '#090E11',
    }).then((theme: any) => {
      const root = document.documentElement.style;
      const hexToRgb = (hex: string): string => {
        const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
        if (!result) return '0, 0, 0';
        return `${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)}`;
      };

      // Accent colors
      root.setProperty('--color-primary', theme['primary']);
      root.setProperty('--color-primary-content', theme['primary-content']);
      root.setProperty('--color-primary-opacity', theme['primary-opacity']);

      // Menu colors
      root.setProperty('--color-menu-bg', theme['menu-bg']);
      root.setProperty('--color-menu-item', theme['menu-item']);
      root.setProperty('--color-menu-darker', theme['menu-darker']);
      root.setProperty('--color-menu-border', theme['menu-border']);
      root.setProperty('--color-menu-divider', theme['menu-divider']);

      // Action colors
      root.setProperty('--color-danger', theme['danger']);
      root.setProperty('--color-danger-alpha', `rgba(${hexToRgb(theme['danger'])}, 0.1)`);
      root.setProperty('--color-success', theme['success']);

      // HUD colors
      root.setProperty('--color-hud-bg', theme['hud-bg']);
      root.setProperty('--color-hud-bg-alpha', `rgba(${hexToRgb(theme['hud-bg'])}, 0.3)`);
      root.setProperty('--color-health-label', theme['health-label']);
      root.setProperty('--color-health-bar', theme['health-bar']);
      root.setProperty('--color-armor-bar', theme['armor-bar']);

      // Chat colors
      root.setProperty('--color-chat-header', theme['chat-header']);
      root.setProperty('--color-chat-header-alpha', `rgba(${hexToRgb(theme['chat-header'])}, 0.2)`);

      dispatch(setTheme(theme));
    })
  }, []);

  return (
      <div className="select-none w-screen h-screen">
        <VisibilityProvider>

          <div className="flex flex-row w-full h-full items-end">
            <Menu>
              {
                !squadId && <>
                  {
                    currentMenu === "squads" && <PublicSquads />
                  }
                  {
                    currentMenu === "create" && <Create />
                  }
                </>
              }
              {
                squadId ? <>
                  {war && (currentMenu === "members" || currentMenu === "leaderboard") && (
                    <WarBanner
                      squad1={war.squad1}
                      squad2={war.squad2}
                      timeLeft={war.timeLeft}
                    />
                  )}
                  {
                    currentMenu === "members" && <Members setChatVisible={setChatVisible} chatVisible={chatVisible} />
                  }
                  {
                    currentMenu === "leaderboard" && <Leaderboard />
                  }
                  {
                    currentMenu === "warTargets" && <WarTargets />
                  }
                  {
                    currentMenu === "settings" && <Settings
                      setChatVisible={setChatVisible}
                    />
                  }
                </> : null
              }
            </Menu>
            <ChatBox
              visible={chatVisible}
              setVisible={setChatVisible}
            />
          </div>

          {challengeData && (
            <WarChallenge
              data={challengeData}
              onClose={() => setChallengeData(null)}
            />
          )}

          {war?.betting && (
            <WarBetting
              squad1={war.squad1}
              squad2={war.squad2}
              betWaitTime={war.betWaitTime || 15}
              minBet={war.minBet || 100}
              maxBet={war.maxBet || 10000}
              myBet={war.myBet}
              onClose={() => {}}
            />
          )}

          {warResultData && (
            <WarResult
              data={warResultData}
              mySquadId={squadId}
              onClose={() => setWarResultData(null)}
            />
          )}

        </VisibilityProvider>
        {personal.hudVisible && <Hud align={personal.hudAlignment} />}
        <ChatNotification
          chatVisible={chatVisible}
        />
      </div>
  );
};

export default App;
