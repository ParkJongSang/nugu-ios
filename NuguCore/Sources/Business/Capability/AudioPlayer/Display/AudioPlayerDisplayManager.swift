//
//  AudioPlayerDisplayManager.swift
//  NuguCore
//
//  Created by MinChul Lee on 2019/07/17.
//  Copyright (c) 2019 SK Telecom Co., Ltd. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

import NuguInterface

final class AudioPlayerDisplayManager: AudioPlayerDisplayManageable {
    private let displayDispatchQueue = DispatchQueue(label: "com.sktelecom.romaine.audio_player_display", qos: .userInitiated)
    
    var playSyncManager: PlaySyncManageable!
    
    private var renderingInfos = [AudioPlayerDisplayRenderingInfo]()
    
    // Current display info
    private var currentItem: AudioPlayerDisplayTemplate?
}

// MARK: - AudioPlayerDisplayManageable

extension AudioPlayerDisplayManager {
    func display(metaData: [String: Any], messageId: String, dialogRequestId: String, playStackServiceId: String?) {
        guard let data = try? JSONSerialization.data(withJSONObject: metaData, options: []),
            let displayItem = try? JSONDecoder().decode(AudioPlayerDisplayTemplate.AudioPlayer.self, from: data) else {
                log.error("Invalid metaData")
            return
        }
        
        displayDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentItem = AudioPlayerDisplayTemplate(
                type: displayItem.template.type,
                typeInfo: .audioPlayer(item: displayItem),
                templateId: messageId,
                dialogRequestId: dialogRequestId,
                playStackServiceId: playStackServiceId
            )
            if let item = self.currentItem {
                self.playSyncManager.startSync(delegate: self, dialogRequestId: item.dialogRequestId, playServiceId: item.playStackServiceId)
            }
        }
    }
    
    func add(delegate: AudioPlayerDisplayDelegate) {
        remove(delegate: delegate)
        
        let info = AudioPlayerDisplayRenderingInfo(delegate: delegate, currentItem: nil)
        renderingInfos.append(info)
    }
    
    func remove(delegate: AudioPlayerDisplayDelegate) {
        renderingInfos.removeAll { (info) -> Bool in
            return info.delegate == nil || info.delegate === delegate
        }
    }
    
    func clearDisplay(delegate: AudioPlayerDisplayDelegate) {
        displayDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            guard let info = self.renderingInfos.first(where: { $0.delegate === delegate }),
                let template = info.currentItem else { return }
            
            self.removeRenderedTemplate(delegate: delegate)
            if self.hasRenderedDisplay(template: template) == false {
                self.playSyncManager.releaseSyncImmediately(dialogRequestId: template.dialogRequestId, playServiceId: template.playStackServiceId)
            }
        }
    }
}

// MARK: - PlaySyncDelegate

extension AudioPlayerDisplayManager: PlaySyncDelegate {
    public func playSyncIsDisplay() -> Bool {
        return true
    }
    
    public func playSyncDuration() -> DisplayTemplate.Duration {
        return .short
    }
    
    public func playSyncDidChange(state: PlaySyncState, dialogRequestId: String) {
        log.info("\(state)")
        displayDispatchQueue.async { [weak self] in
            guard let self = self else { return }
            guard let item = self.currentItem, item.dialogRequestId == dialogRequestId else { return }
            
            switch state {
            case .synced:
                var rendered = false
                self.renderingInfos
                    .compactMap { $0.delegate }
                    .forEach { delegate in
                        if delegate.audioPlayerDisplayShouldRender(template: item) {
                            rendered = true
                            self.setRenderedTemplate(delegate: delegate, template: item)
                        }
                }
                if rendered == false {
                    self.currentItem = nil
                    self.playSyncManager.cancelSync(delegate: self, dialogRequestId: dialogRequestId, playServiceId: item.playStackServiceId)
                }
            case .releasing:
                var cleared = true
                self.renderingInfos
                    .filter { $0.currentItem?.templateId == item.templateId }
                    .compactMap { $0.delegate }
                    .forEach { delegate in
                        if delegate.audioPlayerDisplayShouldClear(template: item) == false {
                            cleared = false
                        }
                }
                if cleared {
                    self.playSyncManager.releaseSync(delegate: self, dialogRequestId: dialogRequestId, playServiceId: item.playStackServiceId)
                }
            case .released:
                if let item = self.currentItem {
                    self.currentItem = nil
                    self.renderingInfos
                        .filter { $0.currentItem?.templateId == item.templateId }
                        .compactMap { $0.delegate }
                        .forEach { self.removeRenderedTemplate(delegate: $0) }
                }
            case .prepared:
                break
            }
        }
    }
}

// MARK: - Private

private extension AudioPlayerDisplayManager {
    func setRenderedTemplate(delegate: AudioPlayerDisplayDelegate, template: AudioPlayerDisplayTemplate) {
        remove(delegate: delegate)
        let info = AudioPlayerDisplayRenderingInfo(delegate: delegate, currentItem: template)
        renderingInfos.append(info)
        delegate.audioPlayerDisplayDidRender(template: template)
    }
    
    func removeRenderedTemplate(delegate: AudioPlayerDisplayDelegate) {
        guard let template = self.renderingInfos.first(where: { $0.delegate === delegate })?.currentItem else { return }
        
        remove(delegate: delegate)
        let info = AudioPlayerDisplayRenderingInfo(delegate: delegate, currentItem: nil)
        renderingInfos.append(info)
        delegate.audioPlayerDisplayDidClear(template: template)
    }
    
    func hasRenderedDisplay(template: AudioPlayerDisplayTemplate) -> Bool {
        return renderingInfos.contains { $0.currentItem?.templateId == template.templateId }
    }
}