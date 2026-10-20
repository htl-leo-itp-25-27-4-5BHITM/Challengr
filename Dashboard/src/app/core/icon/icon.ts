import { Component, Input } from '@angular/core';

/** Linien-Symbole im einheitlichen Stil (1,75 px Strich, Farbe = Textfarbe) statt Emojis. */
@Component({
  selector: 'app-icon',
  standalone: false,
  template: `
    <svg [attr.width]="size" [attr.height]="size" viewBox="0 0 24 24" fill="none" stroke="currentColor"
         stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      @switch (name) {
        @case ('overview') { <path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/> }
        @case ('users') { <circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c.6-3.6 3.2-5.5 6.5-5.5s5.9 1.9 6.5 5.5"/><path d="M16 4.6a3.5 3.5 0 0 1 0 6.8M18.5 14.8c1.7.8 2.8 2.5 3 5.2"/> }
        @case ('flag') { <path d="M5 21V4M5 4h11l-2 4 2 4H5"/> }
        @case ('message') { <path d="M4 5h16v11H9l-5 4z"/> }
        @case ('trophy') { <path d="M8 4h8v5a4 4 0 0 1-8 0zM8 6H4.5a3 3 0 0 0 3.6 4M16 6h3.5a3 3 0 0 1-3.6 4M12 13v4M8.5 20h7M10 17h4"/> }
        @case ('database') { <ellipse cx="12" cy="5.5" rx="7" ry="2.5"/><path d="M5 5.5v13c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5v-13M5 12c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5"/> }
        @case ('refresh') { <path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v4.5h-4.5"/> }
        @case ('check') { <path d="M5 12.5l4.5 4.5L19 7.5"/> }
        @case ('alert') { <path d="M12 4l9 16H3zM12 10v4M12 17.2v.1"/> }
        @case ('crash') { <path d="M13 3L5 13.5h6L10 21l9-11h-6z"/> }
        @case ('user') { <circle cx="12" cy="8" r="3.5"/><path d="M5 20c.7-3.6 3.4-5.5 7-5.5s6.3 1.9 7 5.5"/> }
        @case ('phone') { <rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/> }
        @case ('package') { <path d="M3.5 7.5L12 3l8.5 4.5v9L12 21l-8.5-4.5zM3.5 7.5L12 12l8.5-4.5M12 12v9"/> }
        @case ('battle') { <path d="M4 4l8.5 8.5M14 14l6 6M4 4h3v3M17.5 15.5l3-3M15.5 17.5l-3 3M20 4l-8.5 8.5M10 14l-6 6M20 4h-3v3M6.5 15.5l-3-3M8.5 17.5l3 3"/> }
        @case ('close') { <path d="M6 6l12 12M18 6L6 18"/> }
        @default { <circle cx="12" cy="12" r="2"/> }
      }
    </svg>
  `,
  styles: [':host { display: inline-flex; flex: none; }'],
})
export class Icon {
  @Input() name = '';
  @Input() size = 18;
}
