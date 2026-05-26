class CharacterValidator {
    constructor(profanityRegex) {
        this.profanityRegex = profanityRegex;
        this.validators = {
            firstname: [
                { test: (v) => !!v,                                  message: "Le pseudo est obligatoire." },
                { test: (v) => v.length >= 2,                        message: "Le pseudo doit faire au moins 2 caractères." },
                { test: (v) => v.length <= 20,                       message: "Le pseudo ne peut pas dépasser 20 caractères." },
                { test: (v) => /^[a-zA-Z0-9_\-\.]+$/.test(v),      message: "Le pseudo ne peut contenir que des lettres, chiffres, _, - ou ." },
                { test: (v) => !this.profanityRegex.test(v),         message: "Ce pseudo contient un mot interdit." },
            ],
            gender: [
                { test: (v) => !!v, message: "Choisis un genre." },
            ],
        };
    }

    validateCharacter(character) {
        for (const field in this.validators) {
            if (Object.prototype.hasOwnProperty.call(this.validators, field)) {
                const result = this.validateField(field, character[field]);
                if (!result.isValid) return result;
            }
        }
        return { isValid: true };
    }

    validateField(fieldName, value) {
        const fieldValidators = this.validators[fieldName];
        if (!fieldValidators) return { isValid: true };
        for (const validator of fieldValidators) {
            if (!validator.test(value)) {
                return { isValid: false, field: fieldName, message: validator.message };
            }
        }
        return { isValid: true };
    }
}

let characterValidator;
function initializeValidator() {
    if (typeof profList !== "undefined") {
        const re = "(" + profList.join("|") + ")\\b";
        characterValidator = new CharacterValidator(new RegExp(re, "i"));
    } else {
        characterValidator = new CharacterValidator(/^$/);
    }
}
