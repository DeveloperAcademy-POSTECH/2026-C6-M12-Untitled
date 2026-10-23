//
//  JobStatus.swift
//  Syncy
//
//  Created by martin on 10/22/26.
//

struct JobStatus: Equatable{
    var state: JobStatusState
    var stems: [SessionID]
    var error: String?
}

enum JobStatusState: String{
    case queued, processing, done, error
}
