//
//  OnboardingStep.swift
//  Syncy
//
//  Created by moo on 10/27/26.
//

import Foundation

enum OnboardingStep: Equatable {
    case intro(Int)   // 1~3
    case signIn
    case profile
    case bandChoice
    case bandCreate
    case lineup
    case invite
    case done
}
