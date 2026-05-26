Config = {}

-- Licences Steam des administrateurs qui ont accès à /blanchiradmin
-- Format: "license:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
Config.AdminLicenses = {
    "license:de43671d6e0457044af83c3bfdbc2d9bb5acc96c",
}

-- Modèle de PED par défaut aux spots de blanchiment
Config.PedModel = "s_m_m_fiboffice_01"

-- Liste des modèles disponibles dans le panel admin
Config.PedModels = {
    { model = "s_m_m_fiboffice_01",  label = "Agent (Costume Noir)"  },
    { model = "csb_drug_pos",        label = "Dealer"                },
    { model = "ig_mp_agent14",       label = "Agent Secret"          },
    { model = "u_m_m_filmdirector",  label = "Directeur"             },
    { model = "g_m_m_streetgang_01", label = "Gangster"              },
    { model = "s_m_m_movspace_01",   label = "Technicien"            },
}

-- Taux de conversion : 0.70 = vous récupérez 70% de l'argent (30% de frais)
Config.LaundryRate = 0.70

-- Taux VIP/VIP+ : 0.85 = 15% de frais seulement
Config.LaundryRateVip = 0.85

-- Durée du blanchiment en secondes
Config.LaundryDuration = 60

-- Montant minimum à blanchir par session
Config.MinAmount = 500

-- Montant maximum à blanchir par session
Config.MaxAmount = 1000000

-- Distance d'interaction avec le PED (en mètres)
Config.InteractionDistance = 2.5

-- Cooldown entre deux blanchiments (en secondes, 0 = désactivé)
Config.Cooldown = 300
