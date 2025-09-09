---Job names must be lower case (top level table key)
---@type table<string, Job>
return {
    ['unemployed'] = {
        label = 'Civil',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Freelancer',
                payment = 50,
            },
        },
    },

    ['government'] = {
        type = 'leo',
        label = 'Gouvernement',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Membre du Gouvernement',
            },
            [1] = {
                name = 'Agent Accueil',
            },
            [2] = {
                name = 'Assistant Administratif',
            },
            [3] = {
                name = 'Officier Etat Civil',
            },
            [4] = {
                name = 'Attache de presse',
            },
            [5] = {
                name = 'Agent de recouvrement',
            },
            [6] = {
                name = 'Analyste',
            },
            [7] = {
                name = 'Charge de conformite',
            },
            [8] = {
                name = 'Expert en reglementation',
            },
            [9] = {
                name = 'Controleur fiscal',
            },
            [10] = {
                name = 'Comptable',
            },
            [11] = {
                name = 'Diplomate',
            },
            [12] = {
                name = 'Ambassadeur',
            },
            [13] = {
                name = 'Responsable de Département',
            },
            [14] = {
                name = 'Responsable de Service',
            },
            [15] = {
                name = 'Secrétaire Adjoint',
            },
            [16] = {
                name = 'Secrétaire',
                isboss = true,
            },
            [17] = {
                name = 'Chef de Cabinet',
                isboss = true,
            },
            [18] = {
                name = 'Vice Gouverneur',
                isboss = true,
                bankAuth = true,
            },
            [19] = {
                name = 'Gouverneur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['justice'] = {
        type = 'leo',
        label = 'Department of Justice',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Membre du Department of Justice',
            },
            [1] = {
                name = 'Secrétaire ',
            },
            [2] = {
                name = 'Agent Sécurité',
            },
            [3] = {
                name = 'Avocat',
            },
            [4] = {
                name = 'Huissier Novice',
            },
            [5] = {
                name = 'Substitue du Procureur',
            },
            [6] = {
                name = 'Assesseur',
            },
            [7] = {
                name = 'Juge sous Tutelle',
            },
            [8] = {
                name = 'Huissier',
            },
            [9] = {
                name = 'Procureur',
            },
            [10] = {
                name = 'Juge',
            },
            [11] = {
                name = 'Juge de la Cour d\'Appel',
            },
            [12] = {
                name = 'Juge de la Cour Suprême',
            },
            [13] = {
                name = 'Avocat Général',
                isboss = true,
            },
            [14] = {
                name = 'Chef de Département',
                isboss = true,
            },
            [15] = {
                name = 'Gouverneur',
                isboss = true,
                bankAuth = true,
            },
            [16] = {
                name = 'Chief of Justice',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['police'] = {
        type = 'leo',
        label = 'LSPD',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recrue',
            },
            [1] = {
                name = 'Cadet',
            },
            [2] = {
                name = 'Officier I',
            },
            [3] = {
                name = 'Officier II',
            },
            [4] = {
                name = 'Officier III',
            },
            [5] = {
                name = 'Sergeant',
            },
            [6] = {
                name = 'Sergeant-chef',
            },
            [7] = {
                name = 'Lieutenant',
            },
            [8] = {
                name = 'Lieutenant-chef',
            },
            [9] = {
                name = 'Capitaine',
            },
            [10] = {
                name = 'Commander',
                isboss = true,
                bankAuth = true,
            },
            [11] = {
                name = 'Deputy-chief',
                isboss = true,
                bankAuth = true,
            },
            [12] = {
                name = 'Assistant Chief',
                isboss = true,
                bankAuth = true,
            },
            [13] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['ambulance'] = {
        type = 'ems',
        label = 'EMS',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Stagiaire',
            },
            [1] = {
                name = 'Ambulancier',
            },
            [2] = {
                name = 'Médecin',
            },
            [3] = {
                name = 'Chirurgien',
            },
            [4] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['usss'] = {
        type = 'leo',
        label = 'United States Secret Service',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
            },
            [1] = {
                name = 'Field Agent I',
            },
            [2] = {
                name = 'Field Agent II',
            },
            [3] = {
                name = 'Senior Field Agent',
            },
            [4] = {
                name = 'Special Agent',
            },
            [5] = {
                name = 'Senior Special Agent',
            },
            [5] = {
                name = 'Supervisory Special Agent',
            },
            [6] = {
                name = 'Special Agent In Charge',
            },
            [7] = {
                name = 'Supervisor',
            },
            [8] = {
                name = 'Senior Supervisor',
            },
            [9] = {
                name = 'Lead Supervisor',
            },
            [10] = {
                name = 'Assistant Commander',
                isboss = true,
            },
            [11] = {
                name = 'Assistant Deputy Commander',
                isboss = true,
                bankAuth = true,
            },
            [12] = {
                name = 'Commander',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['dailyglobe'] = {
        label = 'Daily Globe',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['dynasty'] = {
        label = 'Dynasty 8',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recrue',
            },
            [1] = {
                name = 'Agent Immobilier',
            },
            [2] = {
                name = 'Agent Immobilier Senior',
            },
            [3] = {
                name = 'Agent Immobilier Expert',
            },
            [4] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['pdm'] = {
        label = 'Premium Deluxe Motorsport',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['luxuryautos'] = {
        label = 'Luxury Autos',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['cruisin'] = {
        label = 'Cruisin Craftsmen',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['lscustoms'] = {
        label = 'Los Santos Customs',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['burgershot'] = {
        label = 'Burger Shot',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['tsubaki'] = {
        label = 'Tsubaki Sushi',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },

    ['unicorn'] = {
        label = 'Vanilla Unicorn',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },
    ['coffeenoir'] = {
        label = 'Coffee Noir',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Employé',
            },
            [1] = {
                name = 'Directeur',
                isboss = true,
                bankAuth = true,
            },
        },
    },
}
