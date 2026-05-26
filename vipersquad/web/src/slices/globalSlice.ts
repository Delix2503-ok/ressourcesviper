import { createSlice } from '@reduxjs/toolkit';

export interface WarState {
    squad1: { id: number; name: string; score: number };
    squad2: { id: number; name: string; score: number };
    duration: number;
    startTime: number;
    timeLeft: number;
    betting?: boolean;
    betWaitTime?: number;
    minBet?: number;
    maxBet?: number;
    myBet?: number;
}

export interface GlobalState {
    playerId: number | null;
    squadId: number | null;
    squadName: string;
    currentMenu: string;
    isOwner: boolean;
    theme: {
        primary: string;
        primaryContent: string;
    }
    squad: {
        id: number;
        name: string;
        image: string;
        settings: {
            privacy: string;
            memberLimit: number;
        }
    }
    personal: {
        hudVisible: boolean;
        nametagsVisible: boolean;
        blipsVisible: boolean;
        hudAlignment: "left" | "right";
    }
    war: WarState | null;
}

const initialState: GlobalState = {
    playerId: null,
    squadId: 0,
    squadName: 'GFX Squad',
    isOwner: false,
    currentMenu: 'squads',
    theme: {
        primary: '#11c9f7',
        primaryContent: '#FF2F2F'
    },
    squad: {
        id: 1,
        name: 'GFX Squad',
        image: 'https://via.placeholder.com/150',
        settings: {
            privacy: 'public',
            memberLimit: 9,
        }
    },
    personal: {
        hudVisible: true,
        nametagsVisible: true,
        blipsVisible: true,
        hudAlignment: "left"
    },
    war: null
};

const globalSlice = createSlice({
    name: 'global',
    initialState,
    reducers: {
        setSquadId: (state, action) => {
            state.squadId = action.payload;
        },
        setCurrentMenu: (state, action) => {
            const unAuthed = ["create", "squads"]

            if (!state.squadId && !unAuthed.includes(action.payload)) return;
            state.currentMenu = action.payload;
        },
        setPlayerId: (state, action) => {
            state.playerId = action.payload;
        },
        setOwner: (state, action) => {
            state.isOwner = action.payload;
        },
        setPersonalSettings: (state, action) => {
            state.personal = action.payload;
        },
        setTheme: (state, action) => {
            state.theme = action.payload;
        },
        setWar: (state, action) => {
            state.war = action.payload;
        },
        setWarBetting: (state, action) => {
            state.war = {
                squad1: action.payload.squad1,
                squad2: action.payload.squad2,
                duration: action.payload.duration,
                startTime: 0,
                timeLeft: 0,
                betting: true,
                betWaitTime: action.payload.betWaitTime,
                minBet: action.payload.minBet,
                maxBet: action.payload.maxBet,
            };
        },
        setMyBet: (state, action) => {
            if (state.war) {
                state.war.myBet = action.payload;
            }
        },
        updateWarScore: (state, action) => {
            if (state.war) {
                state.war.squad1 = action.payload.squad1;
                state.war.squad2 = action.payload.squad2;
                state.war.timeLeft = action.payload.timeLeft;
            }
        },
        clearWar: (state) => {
            state.war = null;
        }
    },
});

export const { setSquadId, setCurrentMenu, setOwner, setPlayerId, setPersonalSettings, setTheme, setWar, setWarBetting, setMyBet, updateWarScore, clearWar } = globalSlice.actions;
export default globalSlice.reducer;